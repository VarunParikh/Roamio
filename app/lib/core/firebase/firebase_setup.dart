import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:roamio/core/config/flavor.dart';

/// `--dart-define=USE_EMULATORS=true` points a dev build at the local
/// Firebase emulators (docs/SETUP.md) instead of the roamio-dev project.
const _useEmulators = bool.fromEnvironment('USE_EMULATORS');

/// The Android emulator reaches the Mac's localhost at this address.
const _emulatorHost = '10.0.2.2';

/// Initialises Firebase from the flavor's `google-services.json`.
Future<void> setUpFirebase() async {
  await Firebase.initializeApp();
  if (_useEmulators && currentFlavor == Flavor.dev) {
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
  }
}
