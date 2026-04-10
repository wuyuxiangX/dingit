# Dingit App

Flutter client for Dingit — iOS, Android, and (eventually) web. Talks
to the Go server in `apps/server` over REST + WebSocket for realtime
notification delivery.

## Running

```sh
# iOS simulator (macOS only)
flutter run -d iPhone

# Android emulator
flutter run -d emulator-5554

# Web (Chrome)
flutter run -d chrome
```

The app reads `SERVER_URL` / `API_KEY` from `--dart-define` at build
time — e.g. `flutter run --dart-define=SERVER_URL=http://10.0.2.2:8080
--dart-define=API_KEY=xxx`. `10.0.2.2` is the Android emulator's alias
for the host machine's localhost.

## Release signing (Android)

Android release builds read their keystore from
`android/key.properties`. That file is gitignored — you create it
locally once and it never leaves your machine.

### One-time setup

```sh
# 1. Generate an upload keystore (store it OUTSIDE the repo)
keytool -genkey -v \
    -keystore ~/keys/dingit-upload-keystore.jks \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias upload

# 2. Create android/key.properties from the template
cp android/key.properties.template android/key.properties

# 3. Fill in the real values in android/key.properties:
#    - storePassword      (what you typed during keytool -genkey)
#    - keyPassword        (same, unless you asked keytool for a different one)
#    - keyAlias           (upload)
#    - storeFile          (absolute path to the .jks you just generated)
```

### Build

```sh
# Produces app-release.apk signed with the real upload key
flutter build apk --release

# App bundle for the Play Store
flutter build appbundle --release
```

### When `key.properties` is absent

`apps/app/android/app/build.gradle.kts` falls back to signing release
builds with the debug keystore and prints a loud warning to stderr:

```
⚠️  android/key.properties not found — release build will be signed
    with the debug keystore. See android/key.properties.template to
    configure real release signing.
```

This keeps `flutter run --release` and CI smoke builds working on a
fresh clone without a keystore, at the cost of producing an APK that
the Play Store will reject. **Never publish a debug-signed APK.**

### Rotating the keystore

**Don't.** Losing or rotating the upload keystore means the Play
Store will refuse to accept new versions of the same `applicationId`
(`me.dingit.app`) forever. Back up the `.jks` file AND the
`key.properties` you filled in, to at least two places (password
manager + offline drive). Consider enrolling in [Play App Signing](
https://developer.android.com/studio/publish/app-signing#app-signing-google-play)
so Google holds the app signing key — you keep the upload key (lower
blast radius if it leaks) and Google re-signs on your behalf.

## Project structure

```
apps/app/
  lib/
    core/
      api/       — REST + WebSocket clients
      push/      — FCM + APNs integration (server token registration)
      storage/   — SharedPreferences + flutter_secure_storage helpers
      ui/        — shared widgets (buttons, typography)
    app/         — root widget, router, theme
    features/    — per-screen widgets (notifications list, detail, ...)
  android/       — Android host project (Gradle, manifests, signing)
  ios/           — Xcode host project
  scripts/       — dev utilities (check-theme-i18n.sh, etc.)
```

## Tests & lints

```sh
flutter test                       # unit + widget tests
flutter analyze                    # dart analyzer
make check-theme-i18n              # static guard against hex colors
                                   # outside the token layer and
                                   # hard-coded Chinese strings
                                   # outside lib/l10n/
```
