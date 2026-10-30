import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/config/flavor.dart';
import 'package:roamio/core/firebase/firebase_setup.dart';

/// Follow-up S15: App Check runs in the prod app only. It is set up but not
/// enforced (the owner turns enforcement on in the Firebase console).
void main() {
  test('the prod app uses Play Integrity', () {
    expect(usesAppCheck(Flavor.prod, useEmulators: false), isTrue);
  });

  test('never the dev app or the local emulators', () {
    expect(usesAppCheck(Flavor.dev, useEmulators: false), isFalse);
    expect(usesAppCheck(Flavor.dev, useEmulators: true), isFalse);
    expect(usesAppCheck(Flavor.prod, useEmulators: true), isFalse);
  });
}
