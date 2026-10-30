#!/usr/bin/env bash
# End-to-end journey tests (spec §15 Journeys A–F, Task 41) in one go:
# builds the functions, starts the Firebase emulators and an Android
# emulator if they aren't running, runs `flutter test integration_test`
# against them, then stops whatever it started.
#
#   tool/e2e.sh                                   # every integration test
#   tool/e2e.sh integration_test/journeys_test.dart
#   tool/e2e.sh integration_test/journeys_test.dart --plain-name "Journey C"
#
# Settings (environment variables; the defaults suit the owner's Mac):
#   JAVA17_HOME   JDK for Flutter/Gradle   (/opt/homebrew/opt/openjdk@17)
#   JAVA21_HOME   JDK for the emulators    (/opt/homebrew/opt/openjdk@21)
#   FLUTTER       Flutter command          ("fvm flutter")
#   AVD           Android emulator to boot (Roamio_Pixel_API36)
#   ANDROID_HOME  Android SDK              ($HOME/Library/Android/sdk)
#   EMULATOR_FLAGS extra flags for booting the emulator (CI: -gpu swiftshader_indirect)
#   BOOT_TIMEOUT  seconds to wait for the emulator to boot (600)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JAVA17_HOME="${JAVA17_HOME:-/opt/homebrew/opt/openjdk@17}"
JAVA21_HOME="${JAVA21_HOME:-/opt/homebrew/opt/openjdk@21}"
FLUTTER="${FLUTTER:-fvm flutter}"
AVD="${AVD:-Roamio_Pixel_API36}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="$ANDROID_HOME/platform-tools/adb"
LOGS="${E2E_LOGS:-$ROOT/app/build/e2e}"
mkdir -p "$LOGS"

started_firebase=""
started_android=""

cleanup() {
  if [[ -n "$started_firebase" ]]; then
    echo "Stopping the Firebase emulators…"
    kill -INT "$started_firebase" 2>/dev/null || true
    wait "$started_firebase" 2>/dev/null || true
  fi
  if [[ -n "$started_android" ]]; then
    echo "Stopping the Android emulator…"
    "$ADB" -s "$DEVICE" emu kill >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# The dev build needs a google-services.json naming the dev project. Without
# the real one (CI never has it), write a stand-in with no real keys: every
# call goes to the emulators, so only the project and package names matter.
CONFIG="$ROOT/app/android/app/src/dev/google-services.json"
if [[ ! -f "$CONFIG" ]]; then
  echo "No dev google-services.json; writing a stand-in for the emulators."
  # A fresh checkout has no src/dev folder: it only ever holds this file.
  mkdir -p "$(dirname "$CONFIG")"
  cat >"$CONFIG" <<'JSON'
{
  "project_info": {
    "project_number": "000000000000",
    "project_id": "roamio-dev-varun",
    "storage_bucket": "roamio-dev-varun.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:000000000000:android:0000000000000000000000",
        "android_client_info": { "package_name": "app.roamio.android.dev" }
      },
      "oauth_client": [],
      "api_key": [{ "current_key": "AIzaSyStandInKeyForLocalEmulators000000" }],
      "services": { "appinvite_service": { "other_platform_oauth_client": [] } }
    }
  ],
  "configuration_version": "1"
}
JSON
fi

# 1. Firebase emulators, under the dev project ID the app uses.
if curl -sf http://127.0.0.1:5001/roamio-dev-varun/asia-south1/health >/dev/null; then
  echo "Firebase emulators already running."
else
  echo "Building functions and starting the Firebase emulators…"
  (cd "$ROOT/firebase" && npm run build --silent && node scripts/ensure-test-secrets.mjs)
  (cd "$ROOT/firebase" && exec env JAVA_HOME="$JAVA21_HOME" PATH="$JAVA21_HOME/bin:$PATH" \
    firebase emulators:start -P dev --only auth,firestore,functions,storage \
    >"$LOGS/firebase.log" 2>&1) &
  started_firebase=$!
  for _ in $(seq 1 90); do
    curl -sf http://127.0.0.1:5001/roamio-dev-varun/asia-south1/health >/dev/null && break
    sleep 2
  done
  curl -sf http://127.0.0.1:5001/roamio-dev-varun/asia-south1/health >/dev/null || {
    echo "The Firebase emulators didn't start; see $LOGS/firebase.log" >&2
    exit 1
  }
fi

# 2. An Android device: the first one connected, or a headless emulator.
DEVICE="$("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
if [[ -n "$DEVICE" ]]; then
  echo "Using device $DEVICE."
else
  echo "Booting Android emulator $AVD (headless)…"
  "$ANDROID_HOME/emulator/emulator" -avd "$AVD" -no-window -no-audio \
    -no-boot-anim -no-snapshot-save ${EMULATOR_FLAGS:-} >"$LOGS/android.log" 2>&1 &
  started_android=$!
  # Wait at most BOOT_TIMEOUT seconds, and stop early if the emulator dies,
  # showing its log either way (a hung boot otherwise waits for ever).
  boot_failed() {
    echo "$1; the emulator's log:" >&2
    tail -n 80 "$LOGS/android.log" >&2
    exit 1
  }
  deadline=$(( $(date +%s) + ${BOOT_TIMEOUT:-600} ))
  DEVICE=""
  until [[ -n "$DEVICE" && "$("$ADB" -s "$DEVICE" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do
    kill -0 "$started_android" 2>/dev/null || boot_failed "The Android emulator stopped"
    (( $(date +%s) < deadline )) || boot_failed "The Android emulator didn't boot in ${BOOT_TIMEOUT:-600} s"
    sleep 5
    DEVICE="$("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
  done
  echo "Booted $DEVICE in $(( $(date +%s) - deadline + ${BOOT_TIMEOUT:-600} )) s."
fi

# 3. The tests.
targets=("$@")
[[ ${#targets[@]} -eq 0 ]] && targets=(integration_test)
cd "$ROOT/app"
started=$(date +%s)
set +e
JAVA_HOME="$JAVA17_HOME" $FLUTTER test "${targets[@]}" --flavor dev -d "$DEVICE" \
  --dart-define=USE_EMULATORS=true 2>&1 | tee "$LOGS/flutter.log"
status=${PIPESTATUS[0]}
set -e
echo "Finished in $(( $(date +%s) - started )) s (exit $status). Logs: $LOGS"
exit "$status"
