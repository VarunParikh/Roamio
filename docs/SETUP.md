# Developer Setup (macOS, Apple silicon)

Verified 2026-10-27 on macOS 27.0.1, MacBook M5.

## 1. Toolchain

| Tool | Version | Installed with |
|---|---|---|
| Homebrew | 7.0.9 | pre-installed |
| OpenJDK | 17.0.21 | `brew install openjdk@17` |
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

## 5. Firebase and accounts

Covered in Task 3 (to be added here).
