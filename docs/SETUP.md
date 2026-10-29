# Developer Setup (macOS, Apple silicon)

Verified 2026-10-27 on macOS 27.0.1, MacBook M5.

## 1. Toolchain

| Tool | Version | Installed with |
|---|---|---|
| Homebrew | 7.0.9 | pre-installed |
| OpenJDK 17 (Flutter/Android builds) | 17.0.21 | `brew install openjdk@17` |
| OpenJDK 21 (Firebase emulators) | 21.0.13 | `brew install openjdk@21` |
| FVM | 4.3.2 | `brew tap leoafarias/fvm && brew install fvm` |
| Flutter / Dart | 3.47.8 / 3.13.7 (stable) | `fvm install stable && fvm global stable` |
| Firebase CLI | 15.34.1 | `npm install -g firebase-tools` |
| Node | 26.12.0 | pre-installed |
| Android Studio + command-line tools | latest | `brew install --cask android-studio android-commandlinetools` |

Android SDK (in `~/Library/Android/sdk`):

```bash
JAVA_HOME=/opt/homebrew/opt/openjdk@17 sdkmanager --sdk_root=$HOME/Library/Android/sdk --licenses
JAVA_HOME=/opt/homebrew/opt/openjdk@17 sdkmanager --sdk_root=$HOME/Library/Android/sdk \
  "cmdline-tools;latest" "platform-tools" "platforms;android-36" "build-tools;36.0.0" \
  "emulator" "system-images;android-36;google_apis_playstore;arm64-v8a"
```

Point Flutter at them:

```bash
flutter config --jdk-dir /opt/homebrew/opt/openjdk@17 --android-sdk $HOME/Library/Android/sdk --no-analytics
```

## 2. Shell profile

Add to `~/.zshrc`, then open a new terminal:

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/fvm/default/bin:$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
```

## 3. Emulator

```bash
avdmanager create avd -n Roamio_Pixel_API36 -k "system-images;android-36;google_apis_playstore;arm64-v8a" -d pixel_8
emulator -avd Roamio_Pixel_API36
```

Pixel 8, Android 16 (API 36), with Play Store (needed for Google sign-in testing).

## 4. Check

```bash
flutter doctor
```

Expected: ✓ Android toolchain, ✓ Connected device. Xcode warnings are expected until Phase 3 (iOS).

## 5. Firebase

Backend tests run against local emulators (project `demo-roamio`, no cloud access):

```bash
cd firebase && npm ci && npm --prefix functions ci
JAVA_HOME=/opt/homebrew/opt/openjdk@21 npm test
```

Emulator UI while developing: `JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:start --project demo-roamio` → http://127.0.0.1:4000

### Running the app against local emulators

The app identifies itself by the project in its `google-services.json` (`roamio-dev-varun`),
so start the emulators under that ID or the server triggers won't see its writes:

```bash
cd firebase && npm --prefix functions run build
JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:start -P dev --only auth,firestore,functions
# in another terminal
cd app && JAVA_HOME=/opt/homebrew/opt/openjdk@17 fvm flutter run --flavor dev --dart-define=USE_EMULATORS=true
```

Debug builds allow plain-HTTP traffic so the Android emulator can reach the Mac at `10.0.2.2`.
Emails aren't sent; open a verification link from
`http://127.0.0.1:9099/emulator/v1/projects/roamio-dev-varun/oobCodes`.
Google sign-in needs a real Google account on the device and is checked against the real dev project.


| | Dev | Prod |
|---|---|---|
| Project ID | `roamio-dev-varun` | `roamio-prod-varun` |
| Display name | Roamio dev | Roamio |
| Plan | Spark (free) — backend work uses local emulators | Blaze, prepaid via UPI, billing account `0120E9-C10B02-C3ADB8` |
| Firestore | `(default)`, Native, asia-south1 | `(default)`, Native, asia-south1 |
| Storage | — (needs Blaze; use emulator) | `roamio-prod-varun.firebasestorage.app`, asia-south1 |
| Android app | `app.roamio.android.dev` (`1:201519690104:android:368076d8280e6bb50a988d`) | `app.roamio.android` (`1:852804538232:android:43ab98815b8f08b15dc28d`) |
| Sign-in methods | Google, Email/Password | Google, Email/Password |
| SHA fingerprints | debug keystore SHA-1 + SHA-256 | release key — added in Task 42 |
| Gemini in Firebase, Google Analytics | on (owner decision — keep on) | on (owner decision — keep on) |

Aliases live in `firebase/.firebaserc`; use `-P dev` / `-P prod`.

`google-services.json` is **never committed**. Download it locally with
`firebase apps:sdkconfig ANDROID <app-id> -P <alias>`; CI injects it from secrets.

### Email (parental consent)

Functions queue emails in the `mail` collection (Trigger Email extension format) instead of
calling a provider. To send them, install the **Trigger Email from Firestore** extension on prod
with the chosen provider's SMTP settings, collection `mail`. Until then, emails wait in the
collection; in the emulator you can read them in the Emulator UI → Firestore → `mail`.

### Secrets (Cloud Secret Manager, prod)

| Secret | Used by | Set with |
|---|---|---|
| `UNSPLASH_ACCESS_KEY` | banner function (Task 16) | `firebase functions:secrets:set UNSPLASH_ACCESS_KEY -P prod` |

Unsplash app "Roamio" is in demo mode (50 requests/hour). For the dev emulator, put secrets in
`firebase/functions/.secret.local` (gitignored), never in code — e.g. `UNSPLASH_ACCESS_KEY=...`
to fetch real banners locally. Tests use the `demo-roamio` project, whose
`functions/.env.demo-roamio` points banner lookups at a local stand-in for Unsplash.

New machine: a debug keystore's SHA fingerprints must be added to the dev app
(`firebase apps:android:sha:create <dev-app-id> <sha> -P dev`) or Google sign-in fails.
