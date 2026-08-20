#!/bin/sh
set -e

PROJECT=${PROJECT:-unknown}
echo "[${PROJECT}] Starting backend..."

# ── Generate .env from environment variables ──────────────────────────────────
# Laravel requires a physical .env file at /var/www/html/.env.
# Docker env_file / environment: inject vars into the process but NOT into a file.
# We regenerate .env on every start so that changes to envs/<project>.env are
# always picked up (no stale state from a previous container run).
#
# ponytail: write the vars we know Laravel needs; extend the list as needed.
echo "[${PROJECT}] Writing .env from container environment..."
cat > /var/www/html/.env <<EOF
APP_NAME=${APP_NAME:-Laravel}
APP_ENV=${APP_ENV:-local}
APP_KEY=${APP_KEY:-}
APP_DEBUG=${APP_DEBUG:-true}
APP_URL=${APP_URL:-http://localhost}

LOG_CHANNEL=${LOG_CHANNEL:-stack}
LOG_LEVEL=${LOG_LEVEL:-debug}

DB_CONNECTION=${DB_CONNECTION:-pgsql}
DB_HOST=${DB_HOST:-postgres}
DB_PORT=${DB_PORT:-5432}
DB_DATABASE=${DB_DATABASE:-${PROJECT}}
DB_USERNAME=${DB_USERNAME:-postgres}
DB_PASSWORD=${DB_PASSWORD:-}

BROADCAST_DRIVER=${BROADCAST_DRIVER:-log}
CACHE_DRIVER=${CACHE_DRIVER:-redis}
FILESYSTEM_DRIVER=${FILESYSTEM_DRIVER:-local}
QUEUE_CONNECTION=${QUEUE_CONNECTION:-redis}
SESSION_DRIVER=${SESSION_DRIVER:-redis}
SESSION_LIFETIME=${SESSION_LIFETIME:-120}

REDIS_HOST=${REDIS_HOST:-redis}
REDIS_PASSWORD=${REDIS_PASSWORD:-null}
REDIS_PORT=${REDIS_PORT:-6379}

MAIL_MAILER=${MAIL_MAILER:-smtp}
MAIL_HOST=${MAIL_HOST:-}
MAIL_PORT=${MAIL_PORT:-465}
MAIL_USERNAME=${MAIL_USERNAME:-}
MAIL_PASSWORD=${MAIL_PASSWORD:-}
MAIL_ENCRYPTION=${MAIL_ENCRYPTION:-tls}
MAIL_FROM_ADDRESS=${MAIL_FROM_ADDRESS:-}
MAIL_FROM_NAME=${MAIL_FROM_NAME:-Laravel}

JWT_SECRET=${JWT_SECRET:-}
EOF

# Validate APP_KEY — warn loudly but do not abort (artisan key:generate can fix it)
if [ -z "${APP_KEY}" ]; then
    echo "[${PROJECT}] WARNING: APP_KEY is empty. Set it in envs/${PROJECT}.env and recreate the container."
    echo "[${PROJECT}]   docker exec ${PROJECT}_backend php artisan key:generate --show"
fi

# ── Permissions ───────────────────────────────────────────────────────────────
# On Linux/Mac the process may run as www-data (uid 82 on Alpine), so we chown
# in addition to chmod.  On Windows bind mounts chmod is ignored but harmless.
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
chmod -R 775 storage bootstrap/cache 2>/dev/null || true

# Ensure required storage subdirs exist
mkdir -p storage/logs \
         storage/framework/cache \
         storage/framework/sessions \
         storage/framework/views \
         storage/app/public

chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
chmod -R 775 storage bootstrap/cache 2>/dev/null || true

# Install composer deps if vendor is missing
if [ ! -f "vendor/autoload.php" ]; then
    echo "[${PROJECT}] Running composer install..."
    composer install \
        --no-interaction \
        --ignore-platform-reqs \
        --optimize-autoloader \
        --no-progress
fi

# Create storage symlink
if [ ! -e "public/storage" ]; then
    echo "[${PROJECT}] Creating storage:link..."
    php artisan storage:link 2>/dev/null || true
fi

# Pre-cache config and routes — reduces per-request bootstrap from ~300ms to ~30ms
# Regenerated on every container start, so .env changes are always picked up
echo "[${PROJECT}] Caching config and routes..."
php artisan config:cache 2>/dev/null || true
php artisan route:cache  2>/dev/null || true

echo "[${PROJECT}] PHP-FPM ready on :9000"

# Publish version info to shared dashboard volume (optional mount)
if [ -d "/versions" ]; then
    PHP_VER=$(php -r "echo PHP_VERSION;" 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    LARAVEL_VER=$(php artisan --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
    printf '{"php":"%s","laravel":"%s"}\n' "${PHP_VER}" "${LARAVEL_VER}" \
        > /versions/${PROJECT}-backend.json
fi

# Queue worker — runs in background, restarts on failure
php artisan queue:work \
    --timeout=300 \
    --memory=900 \
    --tries=1 \
    --sleep=3 \
    &

exec php-fpm -R
