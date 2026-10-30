import 'package:flutter_test/flutter_test.dart';

import '../support/driver.dart';
import '../support/emulators.dart';

/// Journey D – Offline (spec §15.4): offline, add 3 tabs → reconnect →
/// Sync → every squad member sees them.
///
/// The test switches the app's connection off and on; the app then does
/// what it does for a real outage (Firestore `disableNetwork`, then
/// `enableNetwork` and waiting for queued writes on Sync). Real airplane
/// mode and tabs with photos stay manual checks.
void journeyD() {
  testWidgets('Journey D: tabs added offline sync for the squad', (
    tester,
  ) async {
    final ari = await createPerson('Ari Offline');
    final bob = await createPerson('Bob Online');
    final aid = await seedAdventure(ari, name: 'Ladakh ride', members: [bob]);

    final connection = ScriptedConnection();
    await launch(tester, connection: connection);
    await signInWithEmail(tester, ari.email, password);
    await waitFor(tester, find.text('Hey Ari 👋'));
    await openAdventure(tester, 'Ladakh ride');
    await waitFor(tester, find.text('Squad (2)'));

    // The connection drops.
    connection.set(online: false);
    await waitFor(tester, find.textContaining('You’re offline'));

    for (final name in ['Fuel', 'Momos', 'Permit']) {
      await addSimpleTab(tester, amount: '600', description: name);
      await waitFor(tester, find.text(name));
    }
    // Kept on the phone: the squad can't see them yet.
    await settle(tester, const Duration(seconds: 2));
    expect(await listDocs('adventures/$aid/tabs', as: bob), isEmpty);

    // Back online: Sync sends everything.
    connection.set(online: true);
    await tapOn(tester, find.text('Sync'));
    await waitFor(tester, find.text('Synced ✓'));
    await eventually('Bob sees the 3 tabs', () async {
      final tabs = await listDocs('adventures/$aid/tabs', as: bob);
      return tabs.length == 3 && tabs.every((t) => t['deleted'] == false);
    });
    final tabs = await listDocs('adventures/$aid/tabs', as: bob);
    expect(
      tabs.map((t) => t['description']),
      unorderedEquals(['Fuel', 'Momos', 'Permit']),
    );
    expect(tabs.map((t) => t['createdBy']).toSet(), {ari.uid});

    await signOut(tester);
  });
}
