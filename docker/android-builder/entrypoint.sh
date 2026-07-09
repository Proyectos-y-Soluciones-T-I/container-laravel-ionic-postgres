#!/bin/bash
set -e

BUILD_MODE="${BUILD_MODE:-debug}"

# Allow overrides: --debug or --release
case "$1" in
  --debug)   BUILD_MODE=debug;   shift ;;
  --release) BUILD_MODE=release; shift ;;
esac

echo "[android-builder] BUILD_MODE=${BUILD_MODE}"

# Install deps if missing
if [ ! -d "node_modules" ]; then
    echo "[android-builder] Running npm install..."
    npm install --legacy-peer-deps --no-audit --no-fund
fi

# Add android platform if not present
if [ ! -d "platforms/android" ]; then
    echo "[android-builder] Adding android platform..."
    ionic cordova platform add android
fi

if [ "$BUILD_MODE" = "release" ]; then
    trap 'rm -f /tmp/build.json' EXIT

    # Release signing requires keystore credentials
    if [ -z "$KEYSTORE_PASSWORD" ] || [ -z "$KEY_PASSWORD" ]; then
        echo "[android-builder] KEYSTORE_PASSWORD and KEY_PASSWORD required for release mode"
        exit 1
    fi

    # Generate build.json from env vars for keystore signing (written to /tmp, never into repo)
    cat > /tmp/build.json <<BUILDJSON
{
  "android": {
    "release": {
      "keystore": "/keystore/release.keystore",
      "storePassword": "${KEYSTORE_PASSWORD}",
      "alias": "${KEY_ALIAS:-release}",
      "password": "${KEY_PASSWORD}",
      "packageType": "bundle"
    }
  }
}
BUILDJSON
    echo "[android-builder] build.json generated from env vars"

    echo "[android-builder] Running ionic cordova build android --prod --release"
    ionic cordova build android --prod --release --buildJson=/tmp/build.json

    AAB_PATH="platforms/android/app/build/outputs/bundle/release/app-release.aab"
    if [ -f "$AAB_PATH" ]; then
        echo "[android-builder] ✅ Release AAB produced: $AAB_PATH"
        apksigner_version=$(command -v apksigner 2>/dev/null || echo "not-found")
        if [ "$apksigner_version" != "not-found" ]; then
            apksigner verify --verbose "$AAB_PATH"
        fi
    else
        echo "[android-builder] ❌ Release AAB NOT found at $AAB_PATH"
        exit 1
    fi
else
    echo "[android-builder] Running ionic cordova build android --prod --debug"
    ionic cordova build android --prod --debug

    AAB_PATH="platforms/android/app/build/outputs/bundle/debug/app-debug.aab"
    if [ -f "$AAB_PATH" ]; then
        echo "[android-builder] ✅ Debug AAB produced: $AAB_PATH"
    else
        echo "[android-builder] ❌ Debug AAB NOT found at $AAB_PATH"
        exit 1
    fi
fi
