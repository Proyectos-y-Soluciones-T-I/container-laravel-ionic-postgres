#!/bin/sh
set -e

PROJECT=${PROJECT:-unknown}
echo "[${PROJECT}] Starting frontend..."

# Reliable check: .bin/ng exists only after a successful install
if [ ! -f "node_modules/.bin/ng" ]; then
    echo "[${PROJECT}] Running npm install..."
    if ! npm install --legacy-peer-deps --no-audit --no-fund; then
        echo "[${PROJECT}] Install failed (likely sharp native build). Retrying with --ignore-scripts..."
        npm install --legacy-peer-deps --ignore-scripts --no-audit --no-fund
    fi
fi

# Install @ngx-formly from local zip if requested and not already present
if [ "${INSTALL_FORMLY}" = "yes" ] && [ -f "/tmp/ngx-formly.zip" ]; then
    if [ ! -d "node_modules/@ngx-formly" ]; then
        echo "[${PROJECT}] Extracting @ngx-formly from local zip..."
        unzip -q /tmp/ngx-formly.zip -d node_modules/
        echo "[${PROJECT}] @ngx-formly installed successfully."
    else
        echo "[${PROJECT}] @ngx-formly already present, skipping extraction."
    fi
fi

echo "[${PROJECT}] Ionic/Angular dev server on :4200"
exec ng serve \
    --host 0.0.0.0 \
    --port 4200 \
    --disable-host-check \
    --poll 1000
