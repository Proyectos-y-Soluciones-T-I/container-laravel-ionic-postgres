#!/bin/sh
set -e

echo "[ayudando] Starting frontend..."

# Reliable check: .bin/ng exists only after a successful install
if [ ! -f "node_modules/.bin/ng" ]; then
    echo "[ayudando] Running npm install..."
    if ! npm install --legacy-peer-deps --no-audit --no-fund; then
        echo "[ayudando] Install failed (likely sharp native build). Retrying with --ignore-scripts..."
        npm install --legacy-peer-deps --ignore-scripts --no-audit --no-fund
    fi
fi

echo "[ayudando] Ionic/Angular dev server on :4200"
exec ng serve \
    --host 0.0.0.0 \
    --port 4200 \
    --disable-host-check \
    --poll 1000
