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

echo "[${PROJECT}] Ionic/Angular dev server on :4200"
exec ng serve \
    --host 0.0.0.0 \
    --port 4200 \
    --disable-host-check \
    --poll 1000
