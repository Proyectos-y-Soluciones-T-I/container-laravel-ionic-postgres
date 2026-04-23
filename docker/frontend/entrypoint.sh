#!/bin/sh
set -e

echo "[ayudando] Starting frontend..."

if [ ! -f "node_modules/.package-lock.json" ] && [ ! -f "node_modules/.modules.yaml" ]; then
    echo "[ayudando] Running npm install..."
    if ! npm install --legacy-peer-deps; then
        echo "[ayudando] Install failed (likely sharp native build). Retrying with --ignore-scripts..."
        npm install --legacy-peer-deps --ignore-scripts
    fi
fi

echo "[ayudando] Ionic/Angular dev server on :4200"
exec ng serve \
    --host 0.0.0.0 \
    --port 4200 \
    --disable-host-check \
    --poll 1000
