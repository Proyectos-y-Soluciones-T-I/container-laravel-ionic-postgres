#!/bin/sh
set -e

echo "[ayudando] Starting backend..."

# Force permissions — Windows Docker bind mounts ignore chmod on host,
# but setting 777 ensures the container process (root via zz-docker-user.conf) can write.
chmod -R 777 storage bootstrap/cache 2>/dev/null || true

# Ensure required storage subdirs exist
mkdir -p storage/logs \
         storage/framework/cache \
         storage/framework/sessions \
         storage/framework/views \
         storage/app/public

chmod -R 777 storage bootstrap/cache 2>/dev/null || true

# Install composer deps if vendor is missing
if [ ! -f "vendor/autoload.php" ]; then
    echo "[ayudando] Running composer install..."
    composer install \
        --no-interaction \
        --ignore-platform-reqs \
        --optimize-autoloader \
        --no-progress
fi

# Create storage symlink
if [ ! -e "public/storage" ]; then
    echo "[ayudando] Creating storage:link..."
    php artisan storage:link 2>/dev/null || true
fi

# Pre-cache config and routes — reduces per-request bootstrap from ~300ms to ~30ms
# Regenerated on every container start, so .env changes are always picked up
echo "[ayudando] Caching config and routes..."
php artisan config:cache 2>/dev/null || true
php artisan route:cache  2>/dev/null || true

echo "[ayudando] PHP-FPM ready on :9000"
exec php-fpm -R
