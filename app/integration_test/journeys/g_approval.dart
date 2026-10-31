import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/driver.dart';
import '../support/emulators.dart';

/// Spec UC-21a: a leader with no co-lead approves and rejects a member's tabs
/// on the tab list, their own tab counts at once, and the member resubmits
/// the rejected tab.
void journeyG() {
  testWidgets('Journey G: approve, reject, resubmit', (tester) async {
    final ari = await createPerson('Ari Leader');
    final bob = await createPerson('Bob Member');
    final aid = await seedAdventure(ari, name: 'Goa weekend', members: [bob]);
    await seedFxRates(DateTime.now(), {'INR': '90'});
    Future<String> bobsTab(String description) async {
      expect(
        await createDocAs(
          bob,
          'adventures/$aid/tabs',
          tabDoc(
            createdBy: bob.uid,
            amountMinor: 200000,
            participants: [ari.uid, bob.uid],
            description: description,
          ),
        ),
        200,
      );
      final all = await sharedTabs(aid, as: bob);
      return all.singleWhere((t) => t['description'] == description)['id']!
          as String;
    }

    final dinner = await bobsTab('Dinner');
    final taxi = await bobsTab('Taxi');

    await launch(tester);
    await signInWithEmail(tester, ari.email, password);
    await waitFor(tester, find.text('Hey Ari 👋'));
    await openAdventure(tester, 'Goa weekend');

    Finder rowButton(String tab, String label) => find.descendant(
      of: find.ancestor(of: find.text(tab), matching: find.byType(Card)),
      matching: find.widgetWithText(OutlinedButton, label),
    );

    await scrollTo(tester, find.text('Dinner'));
    await tapOn(tester, rowButton('Dinner', 'Approve'));
    await eventually('Dinner is approved', () async {
      final tab = await getDoc('adventures/$aid/tabs/$dinner');
      return tab?['status'] == 'approved' && tab?['decidedBy'] == ari.uid;
    });

    await scrollTo(tester, find.text('Taxi'));
    await tapOn(tester, rowButton('Taxi', 'Reject'));
    await waitFor(tester, find.text('Reject this tab?'));
    await tester.enterText(find.byType(TextField).last, 'Wrong trip');
    await tapOn(tester, find.widgetWithText(FilledButton, 'Reject'));
    await eventually('Taxi is rejected, with the reason', () async {
      final tab = await getDoc('adventures/$aid/tabs/$taxi');
      return tab?['status'] == 'rejected' &&
          tab?['rejectReason'] == 'Wrong trip';
    });

    // The only admin's own shared tab counts at once.
    await addSimpleTab(tester, amount: '100', description: 'Lunch');
    await eventually('Lunch is approved', () async {
      final all = await sharedTabs(aid, as: bob);
      final lunch = all.where((t) => t['description'] == 'Lunch');
      return lunch.isNotEmpty && lunch.single['status'] == 'approved';
    });
    await signOut(tester);

    // Bob can see why, and resubmits.
    await signInWithEmail(tester, bob.email, password);
    await waitFor(tester, find.text('Hey Bob 👋'));
    await openAdventure(tester, 'Goa weekend');
    await scrollTo(tester, find.text('Rejected: Wrong trip'));
    await tapOn(tester, rowButton('Taxi', 'Edit and resubmit'));
    await saveTab(tester);
    await eventually('Taxi waits again, with no old reason', () async {
      final tab = await getDoc('adventures/$aid/tabs/$taxi');
      return tab?['status'] == 'waiting' && tab?['rejectReason'] == null;
    });

    await signOut(tester);
  });
}
