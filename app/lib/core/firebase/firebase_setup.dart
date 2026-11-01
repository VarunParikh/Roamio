import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:roamio/core/config/flavor.dart';
import 'package:roamio/core/crash/crash_reporter.dart';

/// `--dart-define=USE_EMULATORS=true` points a dev build at the local
/// Firebase emulators (docs/SETUP.md) instead of the roamio-dev project.
const _useEmulators = bool.fromEnvironment('USE_EMULATORS');

/// Whether Firebase runs against the local emulators (no crash reports then).
bool get firebaseUsesEmulators => _useEmulators;

/// The Android emulator reaches the Mac's localhost at this address.
const _emulatorHost = '10.0.2.2';

/// Server functions live in Mumbai (spec §8).
FirebaseFunctions get roamioFunctions =>
    FirebaseFunctions.instanceFor(region: 'asia-south1');

/// Whether to start App Check (follow-up S15): only the prod app, with Play
/// Integrity, and never against the local emulators. It is not enforced:
/// the owner turns enforcement on in the Firebase console once the metrics
/// look right (sideloaded pilot APKs may fail Play Integrity).
bool usesAppCheck(Flavor flavor, {required bool useEmulators}) =>
    flavor == Flavor.prod && !useEmulators;

/// Initialises Firebase from the flavor's `google-services.json`.
Future<void> setUpFirebase() async {
  await Firebase.initializeApp();
  if (!_useEmulators) {
    // Nothing is sent until the age is known (crashCollectionProvider).
    installCrashHandlers();
  }
  if (usesAppCheck(currentFlavor, useEmulators: _useEmulators)) {
    // Play Integrity is the default Android provider.
    await FirebaseAppCheck.instance.activate();
  }
  if (_useEmulators && currentFlavor == Flavor.dev) {
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
    roamioFunctions.useFunctionsEmulator(_emulatorHost, 5001);
    await FirebaseStorage.instance.useStorageEmulator(_emulatorHost, 9199);
  }
}
