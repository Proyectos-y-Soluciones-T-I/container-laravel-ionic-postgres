#!/bin/sh
set -e

echo "[ayudando] Starting backend..."

# Fix storage/cache permissions
chmod -R 775 storage bootstrap/cache 2>/dev/null || true

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

echo "[ayudando] PHP-FPM ready on :9000"
exec php-fpm
