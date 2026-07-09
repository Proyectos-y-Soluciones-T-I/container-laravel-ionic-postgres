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

# Optional @ngx-formly — installs from npm registry on first start only
if [ "${INSTALL_FORMLY:-no}" = "yes" ] && [ ! -d "node_modules/@ngx-formly" ]; then
    echo "[${PROJECT}] Installing @ngx-formly/core..."
    npm install @ngx-formly/core --legacy-peer-deps --no-audit --no-fund
fi

echo "[${PROJECT}] Ionic/Angular dev server on :4200"

# Publish version info to shared dashboard volume (optional mount)
if [ -d "/versions" ]; then
    NODE_VER=$(node --version | tr -d 'v')
    ANGULAR_VER=$(node -e "try{const p=require('/app/package.json');const d=Object.assign({},p.dependencies||{},p.devDependencies||{});const v=(d['@angular/core']||'').replace(/[^0-9.]/g,'');console.log(v.split('.')[0]||'')}catch(e){console.log('')}" 2>/dev/null)
    IONIC_VER=$(node -e "try{const p=require('/app/package.json');const d=Object.assign({},p.dependencies||{},p.devDependencies||{});const v=(d['@ionic/angular']||'').replace(/[^0-9.]/g,'');console.log(v.split('.')[0]||'')}catch(e){console.log('')}" 2>/dev/null)
    printf '{"node":"%s","angular":"%s","ionic":"%s"}\n' "${NODE_VER}" "${ANGULAR_VER}" "${IONIC_VER}" \
        > /versions/${PROJECT}-frontend.json
fi
exec ng serve \
    --host 0.0.0.0 \
    --port 4200 \
    --disable-host-check \
    --poll 1000
