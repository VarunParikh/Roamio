import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'journeys/a_leader.dart';
import 'journeys/b_invitee.dart';
import 'journeys/c_tabs.dart';
import 'journeys/d_offline.dart';
import 'journeys/e_minor.dart';
import 'journeys/f_privacy.dart';
import 'support/emulators.dart';

/// The spec §15 journeys A–F, end to end: the real app on an Android
/// emulator against the local Firebase emulators. The person on the phone
/// uses the UI; everyone else (joiners, parents, squad members) is simulated
/// over the emulators' REST APIs. Run with `tool/e2e.sh` (docs/SETUP.md).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await expectEmulatorsUp();
    await resetEmulators();
  });

  journeyA();
  journeyB();
  journeyC();
  journeyD();
  journeyE();
  journeyF();
}
