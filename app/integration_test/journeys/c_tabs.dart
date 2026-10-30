import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/ui/primary_button.dart';

import '../support/driver.dart';
import '../support/emulators.dart';

/// Journey C – Tabs (spec §15.3): a ₹ tab with 2 payers and custom %
/// including a pal; a € tab; the split report is correct in the viewer's
/// profile currency; balances sum to 0; settling every suggested transfer
/// shows "All square 🎉" for everyone.
///
/// The seeded rates make 1 EUR = 100 INR exactly (90 INR and 0.9 EUR per
/// USD), so every expected amount below is exact:
///
/// | | paid | share | balance |
/// |---|---|---|---|
/// | ₹3,000 dinner: Ari pays ₹2,000, Bob ₹1,000; split 50/30/20 % | | | |
/// | €90 boat: Ari pays; split equally by 3 (₹9,000) | | | |
/// | Ari | ₹11,000 | ₹4,500 | +₹6,500 = +€65 |
/// | Bob | ₹1,000 | ₹3,900 | −₹2,900 = −€29 |
/// | Kiko (pal) | ₹0 | ₹3,600 | −₹3,600 = −€36 |
///
/// −29 − 36 + 65 = 0.
void journeyC() {
  testWidgets('Journey C: tabs in two currencies, split and settled', (
    tester,
  ) async {
    // Ari views in euros; the trip is in rupees.
    final ari = await createPerson('Ari Payer', profileCurrency: 'EUR');
    final bob = await createPerson('Bob Member');
    final aid = await seedAdventure(ari, name: 'Kerala trip', members: [bob]);
    final today = DateTime.now();
    await seedFxRates(today, {'INR': '90', 'EUR': '0.9'});

    await launch(tester);
    await signInWithEmail(tester, ari.email, password);
    await waitFor(tester, find.text('Hey Ari 👋'));
    await openAdventure(tester, 'Kerala trip');
    await waitFor(tester, find.text('Squad (2)'));

    // ₹3,000 dinner: two payers, custom % including the pal.
    await scrollTo(tester, find.text('Add tab'));
    await tapText(tester, 'Add tab');
    await typeInto(tester, 'Amount', '3000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tapOn(tester, find.textContaining('Food & Dining'));
    await typeInto(tester, 'Description (optional)', 'Dinner');
    await tapText(tester, 'Split payment');
    await typeIntoKey(tester, 'pay-${ari.uid}', '2000');
    await typeIntoKey(tester, 'pay-${bob.uid}', '1000');
    await waitFor(tester, find.text('₹3,000.00 of ₹3,000.00 assigned'));
    // Kiko has no app: Ari adds them from here, with a character.
    await scrollTo(tester, find.text('Add pal'));
    await tapText(tester, 'Add pal');
    await addPal(tester, nickname: 'Kiko', character: 'Traveller 3');
    await waitFor(tester, find.widgetWithText(CheckboxListTile, 'Kiko'));
    late final String kiko;
    await eventually('Kiko is saved', () async {
      final pals = await listDocs('adventures/$aid/pals', as: bob);
      if (pals.isEmpty) return false;
      expect(pals.single['characterId'], 'traveller_03');
      kiko = pals.single['id']! as String;
      return true;
    });
    await pickPaidWith(tester, find.byKey(ValueKey('method-${ari.uid}')));
    await pickPaidWith(
      tester,
      find.byKey(ValueKey('method-${bob.uid}')),
      item: '📱 UPI',
    );
    await tapText(tester, 'Custom %');
    await typeIntoKey(tester, 'pct-${ari.uid}', '50');
    await typeIntoKey(tester, 'pct-${bob.uid}', '30');
    await typeIntoKey(tester, 'pct-$kiko', '20');
    await waitFor(tester, find.text('100% of 100% assigned'));
    await saveTab(tester);

    // €90 boat ride, paid by Ari, split equally.
    await addSimpleTab(
      tester,
      amount: '90',
      currency: 'EUR',
      description: 'Boat ride',
    );

    // Both are on the server and the checkTab trigger kept them.
    await eventually('two tabs saved and checked', () async {
      final adventure = await getDoc('adventures/$aid');
      final tabs = await listDocs('adventures/$aid/tabs', as: bob);
      return adventure?['hasTabs'] == true &&
          tabs.length == 2 &&
          tabs.every((t) => t['deleted'] == false);
    });
    final tabs = await listDocs('adventures/$aid/tabs', as: bob);
    final dinner = tabs.singleWhere((t) => t['description'] == 'Dinner');
    expect(dinner['amountMinor'], 300000);
    expect(dinner['currency'], 'INR');
    expect(dinner['percentBp'], {ari.uid: 5000, bob.uid: 3000, kiko: 2000});
    expect(dinner['payers'], [
      {'id': ari.uid, 'amountMinor': 200000},
      {'id': bob.uid, 'amountMinor': 100000},
    ]);
    final boat = tabs.singleWhere((t) => t['description'] == 'Boat ride');
    expect(boat['amountMinor'], 9000);
    expect(boat['currency'], 'EUR');

    // The split, in Ari's euros.
    await tester.pageBack();
    await settle(tester);
    await tapText(tester, 'Split');
    await waitFor(tester, find.text('You’re owed €65.00'));
    await tapText(tester, 'You’re owed €65.00');
    await waitFor(tester, find.text('In INR: You’re owed ₹6,500.00'));
    await tapText(tester, 'See the details');
    await waitFor(tester, find.text('Balances'));
    // Ari, Bob and Kiko's balances, which sum to zero.
    expect(find.text('+€65.00'), findsOneWidget);
    expect(find.text('-€29.00'), findsOneWidget);
    expect(find.text('-€36.00'), findsOneWidget);
    expect(find.text('Kiko pays you'), findsOneWidget);
    expect(find.text('Bob Member pays you'), findsOneWidget);

    // Ari records both suggested transfers (a lead records for the pal).
    for (final row in ['Kiko pays you', 'Bob Member pays you']) {
      await tapOn(tester, _settleOn(row));
      await tapOn(
        tester,
        find.widgetWithText(PrimaryButton, 'Mark as settled'),
      );
      await waitForGone(tester, find.text(row));
    }
    await waitFor(tester, find.text('All square 🎉'));
    expect(find.text('Everyone is square.'), findsOneWidget);
    final paid = await listDocs('adventures/$aid/settlements', as: bob);
    expect(
      {for (final p in paid) p['from']: (p['amountMinor'], p['currency'])},
      {kiko: (360000, 'INR'), bob.uid: (290000, 'INR')},
    );

    // A lead removes Kiko elsewhere: their history still has their name.
    await setDoc('adventures/$aid/pals/$kiko', {
      'nickname': 'Kiko',
      'characterId': 'traveller_03',
      'addedBy': ari.uid,
      'status': 'left',
      'createdAt': DateTime.now().toUtc(),
    });
    await settle(tester, const Duration(seconds: 2));
    expect(find.textContaining('Kiko'), findsWidgets);
    expect(find.text('Deleted user'), findsNothing);

    // Bob, on his own phone, is all square too.
    await signOut(tester);
    await signInWithEmail(tester, bob.email, password);
    await waitFor(tester, find.text('Hey Bob 👋'));
    await tapText(tester, 'Split');
    await waitFor(tester, find.text('All square 🎉'));

    await signOut(tester);
  });
}

Finder _settleOn(String row) => find.descendant(
  of: find.ancestor(of: find.text(row), matching: find.byType(Row)).first,
  matching: find.text('Mark as settled'),
);
