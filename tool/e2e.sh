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
#   E2E_STALL_SECONDS  seconds of silence before a run counts as hung (600)
#   E2E_MAX_UPTIME     reboot a running emulator older than this, seconds (3600)
#
# Exits 75 if the run hung twice (the device, not a test result), else
# Flutter's exit code. Only one run at a time: each wipes the Firebase
# emulators and reinstalls the app, so two would break each other.
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

kill_tree() {
  local child
  for child in $(pgrep -P "$1" 2>/dev/null); do kill_tree "$child" "${2:-TERM}"; done
  kill "-${2:-TERM}" "$1" 2>/dev/null || true
}

# Runs a command for at most $1 seconds: adb itself can hang on a locked device.
limited() {
  local seconds=$1
  shift
  "$@" &
  local pid=$!
  ( sleep "$seconds"; kill_tree "$pid" ) >/dev/null 2>&1 &
  local timer=$!
  local result=0
  wait "$pid" || result=$?
  kill_tree "$timer"
  wait "$timer" 2>/dev/null || true
  return "$result"
}

LOCK="$HOME/.roamio-e2e.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  holder="$(cat "$LOCK/pid" 2>/dev/null || true)"
  if [[ -n "$holder" ]] && kill -0 "$holder" 2>/dev/null; then
    echo "Another e2e run (pid $holder) is using the emulators; wait for it to finish." >&2
    exit 1
  fi
  rm -rf "$LOCK"
  mkdir "$LOCK"
fi
echo $$ >"$LOCK/pid"

started_firebase=""
started_android=""

cleanup() {
  if [[ -n "$started_firebase" ]]; then
    echo "Stopping the Firebase emulators…"
    kill -INT "$started_firebase" 2>/dev/null || true
    for _ in $(seq 1 30); do
      kill -0 "$started_firebase" 2>/dev/null || break
      sleep 1
    done
    kill_tree "$started_firebase" KILL
    wait "$started_firebase" 2>/dev/null || true
  fi
  if [[ -n "$started_android" ]]; then
    echo "Stopping the Android emulator…"
    limited 30 "$ADB" -s "$DEVICE" emu kill >/dev/null 2>&1 || true
    kill_tree "$started_android" KILL
  fi
  rm -rf "$LOCK"
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
if curl -sf -m 5 http://127.0.0.1:5001/roamio-dev-varun/asia-south1/health >/dev/null; then
  echo "Firebase emulators already running."
else
  echo "Building functions and starting the Firebase emulators…"
  (cd "$ROOT/firebase" && npm run build --silent && node scripts/ensure-test-secrets.mjs)
  (cd "$ROOT/firebase" && exec env JAVA_HOME="$JAVA21_HOME" PATH="$JAVA21_HOME/bin:$PATH" \
    firebase emulators:start -P dev --only auth,firestore,functions,storage \
    >"$LOGS/firebase.log" 2>&1) &
  started_firebase=$!
  for _ in $(seq 1 90); do
    curl -sf -m 5 http://127.0.0.1:5001/roamio-dev-varun/asia-south1/health >/dev/null && break
    kill -0 "$started_firebase" 2>/dev/null || break
    sleep 2
  done
  curl -sf -m 5 http://127.0.0.1:5001/roamio-dev-varun/asia-south1/health >/dev/null || {
    echo "The Firebase emulators didn't start; see $LOGS/firebase.log" >&2
    exit 1
  }
fi

# 2. An Android device: the first one connected, or a headless emulator.
first_device() {
  limited 30 "$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }' || true
}

boot_property() {
  limited 30 "$ADB" -s "$DEVICE" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true
}

start_emulator() {
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
  local deadline=$(( $(date +%s) + ${BOOT_TIMEOUT:-600} ))
  DEVICE=""
  until [[ -n "$DEVICE" && "$(boot_property)" == "1" ]]; do
    kill -0 "$started_android" 2>/dev/null || boot_failed "The Android emulator stopped"
    (( $(date +%s) < deadline )) || boot_failed "The Android emulator didn't boot in ${BOOT_TIMEOUT:-600} s"
    sleep 5
    DEVICE="$(first_device)"
  done
  echo "Booted $DEVICE in $(( $(date +%s) - deadline + ${BOOT_TIMEOUT:-600} )) s."
}

# A fresh emulator if this script started it; otherwise reboots the device.
restart_device() {
  if [[ -n "$started_android" ]]; then
    kill_tree "$started_android" KILL
    wait "$started_android" 2>/dev/null || true
    start_emulator
    return
  fi
  limited 60 "$ADB" -s "$DEVICE" reboot || true
  sleep 15
  local deadline=$(( $(date +%s) + ${BOOT_TIMEOUT:-600} ))
  until [[ "$(boot_property)" == "1" ]]; do
    if (( $(date +%s) >= deadline )); then
      echo "$DEVICE didn't come back after a reboot." >&2
      exit 1
    fi
    sleep 5
  done
}

# Asks Android's activity manager, which stops answering when Android locks up.
device_answers() {
  [[ "$(limited 30 "$ADB" -s "$DEVICE" shell am get-current-user 2>/dev/null | tr -d '\r')" =~ ^[0-9]+$ ]]
}

DEVICE="$(first_device)"
if [[ -n "$DEVICE" ]]; then
  echo "Using device $DEVICE."
  uptime="$(limited 30 "$ADB" -s "$DEVICE" shell cut -d. -f1 /proc/uptime 2>/dev/null | tr -d '\r' || true)"
  if ! device_answers; then
    echo "$DEVICE isn't responding; rebooting it…"
    restart_device
  elif [[ "$DEVICE" == emulator-* && "$uptime" =~ ^[0-9]+$ && "$uptime" -gt "${E2E_MAX_UPTIME:-3600}" ]]; then
    echo "$DEVICE has been up $(( uptime / 60 )) minutes; rebooting it for a clean run…"
    restart_device
  fi
else
  start_emulator
fi

# 3. The tests, watched. If Android locks up the journeys hang without a word
# and nothing stops them, so silence longer than any build or journey (CI's
# longest is about 6 minutes, the first Gradle build) ends the run. A hang
# gets one retry on a restarted device; a test that fails never does.
STALL_SECONDS="${E2E_STALL_SECONDS:-600}"
targets=("$@")
[[ ${#targets[@]} -eq 0 ]] && targets=(integration_test)
cd "$ROOT/app"

# Sets `status` to the tests' exit code and `stalled` to whether they hung.
run_tests() {
  stalled=""
  : >"$LOGS/flutter.log"
  JAVA_HOME="$JAVA17_HOME" $FLUTTER test "${targets[@]}" --flavor dev -d "$DEVICE" \
    --dart-define=USE_EMULATORS=true > >(tee -a "$LOGS/flutter.log") 2>&1 &
  local tests=$! size=0 latest last_change
  last_change=$(date +%s)
  while kill -0 "$tests" 2>/dev/null; do
    sleep 5
    latest=$(wc -c <"$LOGS/flutter.log")
    if (( latest != size )); then
      size=$latest
      last_change=$(date +%s)
    elif (( $(date +%s) - last_change >= STALL_SECONDS )); then
      stalled=yes
      kill_tree "$tests"
      sleep 5
      kill_tree "$tests" KILL
      break
    fi
  done
  wait "$tests"
  status=$?
}

started=$(date +%s)
set +e
run_tests
if [[ -n "$stalled" ]]; then
  echo "No output for $STALL_SECONDS s: the run hung. Keeping its logs as $LOGS/*-at-hang.*"
  cp "$LOGS/flutter.log" "$LOGS/flutter-at-hang.log"
  limited 60 "$ADB" -s "$DEVICE" logcat -d >"$LOGS/logcat-at-hang.txt" 2>&1
  restart_device
  echo "Trying once more on the restarted device…"
  run_tests
  if [[ -n "$stalled" ]]; then
    echo "It hung again on a restarted device; giving up." >&2
    status=75
  fi
fi
set -e
echo "Finished in $(( $(date +%s) - started )) s (exit $status). Logs: $LOGS"
exit "$status"
