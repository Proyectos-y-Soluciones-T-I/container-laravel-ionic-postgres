#!/bin/sh
set -e

echo "[ayudando] Starting frontend..."

# Install deps if node_modules is empty (named volume, first boot)
if [ ! -f "node_modules/.package-lock.json" ] && [ ! -f "node_modules/.modules.yaml" ]; then
    echo "[ayudando] Running npm install..."
    npm install --legacy-peer-deps
fi

echo "[ayudando] Ionic/Angular dev server on :4200"
exec ng serve \
    --host 0.0.0.0 \
    --port 4200 \
    --disable-host-check \
    --poll 1000
