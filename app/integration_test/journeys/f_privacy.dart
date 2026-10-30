import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/ui/primary_button.dart';

import '../support/driver.dart';
import '../support/emulators.dart';

/// Journey F – Privacy (spec §15.6): a budget alert at 80% reaches only its
/// owner; data export and account deletion complete.
void journeyF() {
  testWidgets('Journey F: private budget alert, export, delete', (
    tester,
  ) async {
    final ari = await createPerson('Ari Private');
    final bob = await createPerson('Bob Leader');
    // Bob leads, so Ari can delete her account without handing over.
    final aid = await seedAdventure(bob, name: 'Pune weekend', members: [ari]);

    final shared = await launch(tester);
    await signInWithEmail(tester, ari.email, password);
    await waitFor(tester, find.text('Hey Ari 👋'));

    // Ari sets a ₹10,000 budget; only she can see it.
    await tapText(tester, 'Split');
    await waitFor(tester, find.text('Only you can see your budget.'));
    await tapText(tester, 'Set a budget');
    await typeInto(tester, 'Budget', '10000');
    await tapOn(tester, find.widgetWithText(PrimaryButton, 'Save budget'));
    await waitFor(tester, find.textContaining('of ₹10,000.00 used'));
    await eventually(
      'the budget is saved',
      () async => await getDoc('adventures/$aid/budgets/${ari.uid}') != null,
    );
    expect(await readStatus('adventures/$aid/budgets/${ari.uid}', bob), 403);

    // Bob adds a ₹16,000 tab shared with Ari: her share is ₹8,000 = 80%.
    expect(
      await createDocAs(
        bob,
        'adventures/$aid/tabs',
        tabDoc(
          createdBy: bob.uid,
          amountMinor: 1600000,
          participants: [ari.uid, bob.uid],
          description: 'Villa',
        ),
      ),
      200,
    );

    // The alert reaches Ari's Home, and nobody else.
    await tapText(tester, 'Home');
    await waitFor(
      tester,
      find.text('You’ve used 80% of your Pune weekend budget'),
    );
    final alert = (await getDoc(
      'users/${ari.uid}/notifications/${aid}_budget_80',
    ))!;
    expect(alert['type'], 'budget_alert');
    final bobsCards = await listDocs('users/${bob.uid}/notifications');
    expect(bobsCards.where((n) => n['type'] == 'budget_alert'), isEmpty);
    expect(
      await readStatus('users/${ari.uid}/notifications/${aid}_budget_80', bob),
      403,
    );

    // Download my data: the JSON includes her budget.
    await tapText(tester, 'You');
    await scrollTo(tester, find.text('Privacy centre'));
    await tapText(tester, 'Privacy centre');
    await tapText(tester, 'Download my data');
    await waitFor(
      tester,
      find.text('Your files are ready. Save them somewhere safe.'),
      timeout: const Duration(seconds: 60),
    );
    expect(shared.names.single.first, 'Roamio data.json');
    final export = utf8.decode(await shared.files.single.first.readAsBytes());
    expect(export, contains('Ari Private'));
    expect(export, contains('Pune weekend'));
    expect(export, contains('1000000')); // the budget, in paise

    // Delete my account: signed out, data gone, the squad's tab stays.
    await scrollTo(tester, find.text('Delete my account'));
    await tapText(tester, 'Delete my account');
    await waitFor(tester, find.text('Delete your account?'));
    await tapText(tester, 'Delete');
    await waitFor(
      tester,
      find.text('Continue with Google'),
      timeout: const Duration(seconds: 60),
    );
    expect(await uidForEmail(ari.email), isNull);
    expect(await getDoc('users/${ari.uid}'), isNull);
    expect(await getDoc('adventures/$aid/budgets/${ari.uid}'), isNull);
    final adventure = (await getDoc('adventures/$aid'))!;
    expect(adventure['memberUids'], isNot(contains(ari.uid)));
    final tabs = await listDocs('adventures/$aid/tabs', as: bob);
    expect(tabs.single['participants'], contains(ari.uid));
    final audit = await listDocs('auditLog');
    expect(
      audit.where(
        (e) => e['action'] == 'account_deleted' && e['target'] == ari.uid,
      ),
      hasLength(1),
    );
  });
}
