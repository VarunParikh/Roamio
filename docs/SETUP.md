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
JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:start -P dev --only auth,firestore,functions,storage
# in another terminal
cd app && JAVA_HOME=/opt/homebrew/opt/openjdk@17 fvm flutter run --flavor dev --dart-define=USE_EMULATORS=true
```

Debug builds allow plain-HTTP traffic so the Android emulator can reach the Mac at `10.0.2.2`.
Emails aren't sent; open a verification link from
`http://127.0.0.1:9099/emulator/v1/projects/roamio-dev-varun/oobCodes`.
Google sign-in needs a real Google account on the device and is checked against the real dev project.

### End-to-end journey tests (Task 41)

`app/integration_test/journeys_test.dart` runs the spec §15 journeys A–F on the
Android emulator against the Firebase emulators: the person on the phone uses
the real app, and everyone else (joiners, the parent, other squad members) is
simulated through the emulators' REST APIs. One command does it all:

```bash
tool/e2e.sh
```

It builds the functions, starts the Firebase emulators and `Roamio_Pixel_API36`
(headless) if they aren't already running, runs `flutter test integration_test`,
then stops whatever it started. Logs go to `app/build/e2e/`. To run one file or
one journey:

```bash
tool/e2e.sh integration_test/journeys_test.dart --plain-name "Journey C"
```

The script guards against a locked-up device: only one run at a time, a running
emulator up for over an hour is rebooted first, and 10 minutes without output
counts as a hang. A hang keeps its logs as `app/build/e2e/*-at-hang.*` and gets one
retry on a restarted device; a second hang exits 75. A test that fails is never
retried.

The journeys take about 3 minutes; a cold start (booting both emulators) about
4. Without a dev `google-services.json` the script writes a stand-in with no
real keys, which is enough because every call goes to the emulators. CI runs
the same script nightly (`.github/workflows/e2e.yml`). A scheduled run that
doesn't pass opens a GitHub Issue labelled `nightly-failure`. Every morning at
about 03:00 India time, the Claude routine "Roamio nightly journey check"
(claude.ai/code/routines) looks at the run. On a failure it opens a
"Fix nightly journeys: …" PR that closes the issue; it never merges.

Still manual: installing the APK from an invite link, real airplane mode,
photos on tabs, Google sign-in, real emails and push notifications.


| | Dev | Prod |
|---|---|---|
| Project ID | `roamio-dev-varun` | `roamio-prod-varun` |
| Display name | Roamio dev | Roamio |
| Plan | Blaze (since 2026-10-31), ₹500 budget | Blaze, prepaid via UPI, billing account `0120E9-C10B02-C3ADB8` |
| Firestore | `(default)`, Native, asia-south1 | `(default)`, Native, asia-south1 |
| Storage | `roamio-dev-varun.firebasestorage.app`, asia-south1 | `roamio-prod-varun.firebasestorage.app`, asia-south1 |
| Android app | `app.roamio.android.dev` (`1:201519690104:android:368076d8280e6bb50a988d`) | `app.roamio.android` (`1:852804538232:android:43ab98815b8f08b15dc28d`) |
| Sign-in methods | Google, Email/Password | Google, Email/Password |
| SHA fingerprints | debug keystore SHA-1 + SHA-256 | release key — added in Task 42 |
| Gemini in Firebase, Google Analytics | on (owner decision — keep on) | on (owner decision — keep on) |

Aliases live in `firebase/.firebaserc`; use `-P dev` / `-P prod`.

`google-services.json` is **never committed**. Download it locally with
`firebase apps:sdkconfig ANDROID <app-id> -P <alias>`; CI injects it from secrets.

### App Check (set up, not enforced)

The prod app starts Firebase App Check with Play Integrity
(`usesAppCheck` in `app/lib/core/firebase/firebase_setup.dart`); the dev app and
the emulators don't. Nothing is enforced yet, so a phone that fails the check
still works. Sideloaded pilot APKs may fail Play Integrity, so don't enforce
during the pilot. To enforce later (owner, after the app is on the Play Store):

1. Play Console → Roamio → Release → App integrity → link the Google Cloud
   project `roamio-prod-varun`.
2. Firebase console → roamio-prod-varun → App Check → Apps → Roamio Android →
   register with **Play Integrity** and the release key's SHA-256.
3. Install the prod APK, use it, and confirm its requests count as verified. Watch App Check → APIs → *Verified requests* for a week. When almost all
   are verified, press **Enforce** for Cloud Firestore, Cloud Storage and
   Cloud Functions, one at a time.

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
