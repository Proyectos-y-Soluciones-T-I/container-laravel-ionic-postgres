# Mobile App — Production Build Guide

This guide covers the full process to build, sign, and publish the Android and iOS apps for **Ayudando**, **Emergencias**, and **Fiscalización**.

> All build commands run inside the frontend source directory of each project:
> `src/<project>/frontend/`

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Node.js | 18.x | Match the Docker image |
| Ionic CLI | 7.x | `npm install -g @ionic/cli@7` |
| Cordova | Latest | `npm install -g cordova` |
| Java JDK | 17 | Required for `jarsigner` |
| Android SDK Build-Tools | 34 or 35 | Via Android Studio |
| Xcode | Latest | macOS only — for iOS |

---

## Step 1 — Pre-build checks

**`angular.json`** — confirm `outputPath` is set to `www`:

```json
"outputPath": "www"
```

**`config.xml`** — bump the version number on line 2 before every release:

```xml
<widget ... version="2.10.3" ...>
```

---

## Step 2 — Prepare the app

Compiles the Angular/Ionic app and copies assets into the native platform folder.

```bash
# Android
ionic cordova prepare android --prod

# iOS
ionic cordova prepare ios --prod
```

---

## Step 3 — Development build (test against production server)

Use this to install on a device for QA before release.

```bash
# Android — generates app-debug.apk
ionic cordova build android --prod

# iOS — opens app directly on connected iPhone
ionic cordova run ios --prod
```

**Android APK location:**

```
platforms/android/app/build/outputs/apk/debug/app-debug.apk
```

---

## Step 4 — Release build

Generates an unsigned release artifact for store submission.

```bash
# Android — generates app-release.aab (App Bundle)
ionic cordova build android --prod --release

# iOS — generates archive for Xcode
ionic cordova build ios --prod --release
```

---

## Step 5 — Sign the Android app

Each project has its own keystore. Run these commands from the project's `frontend/` directory.

### Ayudando

```bash
# Sign
"C:/Program Files/Java/jdk-17/bin/jarsigner.exe" \
  -verbose \
  -sigalg SHA1withRSA \
  -digestalg SHA1 \
  -keystore pys_ayudando.keystore \
  platforms/android/app/build/outputs/bundle/release/app-release.aab \
  ayudando
# Password: pysayudando

# Align
"C:/Users/pys_a/AppData/Local/Android/Sdk/build-tools/35.0.0/zipalign.exe" \
  -v 4 \
  platforms/android/app/build/outputs/bundle/release/app-release.aab \
  Ayudando-caracterizacion-<version>.aab
```

### Fiscalización

```bash
# Sign
"C:/Program Files/Java/jdk-17/bin/jarsigner.exe" \
  -verbose \
  -sigalg SHA1withRSA \
  -digestalg SHA1 \
  -keystore ayudando_fiscalizacion.keystore \
  platforms/android/app/build/outputs/bundle/release/app-release.aab \
  ayudando_fiscalizacion
# Password: pys_fiscalizacion

# Align
"C:/Users/pys_a/AppData/Local/Android/Sdk/build-tools/34.0.0/zipalign.exe" \
  -v 4 \
  platforms/android/app/build/outputs/bundle/release/app-release.aab \
  Ayudando-Fiscalizacion-<version>.aab
```

### Emergencias

```bash
# Sign
"C:/Program Files/Java/jdk-17/bin/jarsigner.exe" \
  -verbose \
  -sigalg SHA1withRSA \
  -digestalg SHA1 \
  -keystore emergencias_key.keystore \
  platforms/android/app/build/outputs/bundle/release/app-release.aab \
  emergencias_key
# Password: pys_emergencias

# Align
"C:/Users/pys_a/AppData/Local/Android/Sdk/build-tools/35.0.0/zipalign.exe" \
  -v 4 \
  platforms/android/app/build/outputs/bundle/release/app-release.aab \
  Ayudando-emergencias-<version>.aab
```

> Replace `<version>` with the version set in `config.xml` (e.g. `2.10.3`).

---

## Step 6 — iOS build and archive (Xcode)

From the project's `frontend/` directory:

```bash
# Ayudando
open platforms/ios/ayudando.xcworkspace

# Fiscalización
open platforms/ios/fiscalizacion.xcworkspace

# Emergencias
open platforms/ios/emergencias.xcworkspace
```

In Xcode:

1. Select the correct scheme and a real device (or **Any iOS Device**).
2. **Product → Archive** — wait for the build to complete.
3. In the **Archives** window: select the archive → **Validate App** → fix any issues.
4. **Distribute App** → **App Store Connect** → follow the wizard.

---

## Keystore reference

| Project | Keystore file | Alias | Build-tools version |
|---|---|---|---|
| Ayudando | `pys_ayudando.keystore` | `ayudando` | 35.0.0 |
| Fiscalización | `ayudando_fiscalizacion.keystore` | `ayudando_fiscalizacion` | 34.0.0 |
| Emergencias | `emergencias_key.keystore` | `emergencias_key` | 35.0.0 |

> Keystores are stored inside each project's `frontend/` directory.
> **Never commit keystores to source control.** Back them up in a secure location.

---

## Checklist before publishing

- [ ] `config.xml` version bumped
- [ ] Tested on a real device with `--prod` build
- [ ] Screenshots and store metadata up to date
- [ ] Signed `.aab` verified with `jarsigner -verify`
- [ ] iOS archive validated without errors in Xcode
- [ ] Backup of signed `.aab` and `.ipa` saved externally
