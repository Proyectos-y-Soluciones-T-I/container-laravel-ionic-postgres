# Mobile App — Production Build Guide

This guide covers the full process to build, sign, and publish the Android and iOS apps
for **Ayudando**, **Emergencias**, and **Fiscalización**.

The build is split across two environments:

| Phase | Where | Why |
|---|---|---|
| Web compilation (`ionic build`) | Docker container | Node 18 + deps already installed in the volume |
| Cordova prepare + native build | Host machine | Requires Android SDK / Xcode — not in the container |
| Signing (`jarsigner`, `zipalign`) | Host machine (Windows) | JDK and Android SDK tools are local |
| iOS archive | macOS host | Xcode only runs on macOS |

---

## Prerequisites

### Host machine

| Tool | Version | Notes |
|---|---|---|
| Java JDK | 17 | For `jarsigner` — `C:/Program Files/Java/jdk-17/` |
| Android SDK Build-Tools | 34 or 35 | Via Android Studio |
| Ionic CLI | 7.x | `npm install -g @ionic/cli@7` |
| Cordova | Latest | `npm install -g cordova` |
| Xcode | Latest | macOS only — for iOS |

### Docker container (already available)

- Node 18.16.1
- Ionic CLI 7
- Angular CLI 17
- All `node_modules` installed in the named volume

---

## Step 1 — Pre-build checks

Open `src/<project>/frontend/` and verify:

**`angular.json`** — `outputPath` must be `www`:

```json
"outputPath": "www"
```

**`config.xml`** — bump the version on line 2 before every release:

```xml
<widget ... version="2.10.3" ...>
```

---

## Step 2 — Web compilation (inside the Docker container)

The container must be running. If it is not:

```bash
docker compose -f docker-compose.ayudando.yml --project-name ayudando up -d
# Wait for: ✔ Compiled successfully.
docker compose -f docker-compose.ayudando.yml --project-name ayudando logs -f frontend
```

Run the production build:

```bash
# Replace ayudando with emergencias or fiscalizacion
docker exec ayudando_frontend ionic build --prod
```

For a specific Angular configuration:

```bash
docker exec ayudando_frontend ionic build --prod --configuration=production
```

The output lands in the bind-mounted source on the host:

```
src/ayudando/frontend/www/
```

Verify:

```bash
docker exec ayudando_frontend ls -lh /app/www
```

---

## Step 3 — Prepare native platforms (host machine)

Run these from `src/<project>/frontend/` on the host.
Cordova picks up the `www/` generated in the previous step.

```bash
# Android
ionic cordova prepare android --prod

# iOS
ionic cordova prepare ios --prod
```

---

## Step 4 — Development build for QA (host machine)

Use this to test on a device before release, pointing at the production server.

```bash
# Android — generates app-debug.apk
ionic cordova build android --prod

# iOS — opens app directly on connected iPhone
ionic cordova run ios --prod
```

Android APK location:

```
platforms/android/app/build/outputs/apk/debug/app-debug.apk
```

---

## Step 5 — Release build (host machine)

Generates the unsigned release artifact for store submission.

```bash
# Android — generates app-release.aab
ionic cordova build android --prod --release

# iOS
ionic cordova build ios --prod --release
```

---

## Step 6 — Sign the Android app (Windows host)

Run these from `src/<project>/frontend/`.

### Ayudando

```bash
# Sign
"C:/Program Files/Java/jdk-17/bin/jarsigner.exe" ^
  -verbose ^
  -sigalg SHA1withRSA ^
  -digestalg SHA1 ^
  -keystore pys_ayudando.keystore ^
  platforms/android/app/build/outputs/bundle/release/app-release.aab ^
  ayudando
# Password: pysayudando

# Align
"C:/Users/pys_a/AppData/Local/Android/Sdk/build-tools/35.0.0/zipalign.exe" ^
  -v 4 ^
  platforms/android/app/build/outputs/bundle/release/app-release.aab ^
  Ayudando-caracterizacion-<version>.aab
```

### Fiscalización

```bash
# Sign
"C:/Program Files/Java/jdk-17/bin/jarsigner.exe" ^
  -verbose ^
  -sigalg SHA1withRSA ^
  -digestalg SHA1 ^
  -keystore ayudando_fiscalizacion.keystore ^
  platforms/android/app/build/outputs/bundle/release/app-release.aab ^
  ayudando_fiscalizacion
# Password: pys_fiscalizacion

# Align
"C:/Users/pys_a/AppData/Local/Android/Sdk/build-tools/34.0.0/zipalign.exe" ^
  -v 4 ^
  platforms/android/app/build/outputs/bundle/release/app-release.aab ^
  Ayudando-Fiscalizacion-<version>.aab
```

### Emergencias

```bash
# Sign
"C:/Program Files/Java/jdk-17/bin/jarsigner.exe" ^
  -verbose ^
  -sigalg SHA1withRSA ^
  -digestalg SHA1 ^
  -keystore emergencias_key.keystore ^
  platforms/android/app/build/outputs/bundle/release/app-release.aab ^
  emergencias_key
# Password: pys_emergencias

# Align
"C:/Users/pys_a/AppData/Local/Android/Sdk/build-tools/35.0.0/zipalign.exe" ^
  -v 4 ^
  platforms/android/app/build/outputs/bundle/release/app-release.aab ^
  Ayudando-emergencias-<version>.aab
```

> Replace `<version>` with the value set in `config.xml` (e.g. `2.10.3`).

---

## Step 7 — iOS archive (macOS host, Xcode)

From `src/<project>/frontend/`:

```bash
open platforms/ios/ayudando.xcworkspace      # Ayudando
open platforms/ios/fiscalizacion.xcworkspace  # Fiscalización
open platforms/ios/emergencias.xcworkspace    # Emergencias
```

In Xcode:

1. Select the correct scheme and **Any iOS Device**.
2. **Product → Archive** — wait for the build to complete.
3. In the **Archives** window: select the archive → **Validate App** → fix any issues.
4. **Distribute App** → **App Store Connect** → follow the wizard.

---

## Keystore reference

| Project | Keystore file | Alias | Build-tools |
|---|---|---|---|
| Ayudando | `pys_ayudando.keystore` | `ayudando` | 35.0.0 |
| Fiscalización | `ayudando_fiscalizacion.keystore` | `ayudando_fiscalizacion` | 34.0.0 |
| Emergencias | `emergencias_key.keystore` | `emergencias_key` | 35.0.0 |

> Keystores live in each project's `frontend/` directory.
> **Never commit keystores to source control.** Back them up in a secure location.

---

## Full workflow summary

```
1. docker exec <project>_frontend ionic build --prod
        ↓ generates src/<project>/frontend/www/
2. ionic cordova prepare android --prod          (host)
3. ionic cordova build android --prod --release  (host)
        ↓ generates app-release.aab
4. jarsigner ...                                 (host, Windows)
5. zipalign ...                                  (host, Windows)
        ↓ signed + aligned .aab ready for Play Store
```

---

## Checklist before publishing

- [ ] `config.xml` version bumped
- [ ] `docker exec <project>_frontend ionic build --prod` completed without errors
- [ ] `www/` directory present in `src/<project>/frontend/`
- [ ] Tested on a real device with `--prod` build
- [ ] Screenshots and store metadata up to date
- [ ] Signed `.aab` verified: `jarsigner -verify -verbose <file>.aab`
- [ ] iOS archive validated without errors in Xcode
- [ ] Backup of signed `.aab` and `.ipa` saved externally
