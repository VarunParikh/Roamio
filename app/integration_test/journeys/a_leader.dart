import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/driver.dart';
import '../support/emulators.dart';

/// Journey A – Leader (spec §15.1): sign up → create adventure → share
/// invite → promote a joiner to co-lead → add a pal.
void journeyA() {
  testWidgets('Journey A: a leader sets up a squad', (tester) async {
    final shared = await launch(tester);
    final email = uniqueEmail('ari');

    // Sign up with email, then verify it.
    final uid = await signUpWithEmail(
      tester,
      name: 'Ari Lead',
      email: email,
      dob: DateTime(1995, 6, 15),
    );
    await waitFor(tester, find.text('Hey Ari 👋'));
    expect((await getDoc('users/$uid/private/account'))!['ageStatus'], 'adult');

    // Create an adventure in Thailand happening now.
    await tapText(tester, 'New Adventure');
    await tapText(tester, 'Choose a country');
    await tester.enterText(find.byType(TextField).last, 'thai');
    await tapText(tester, 'Thailand');
    await tapText(tester, 'Next');
    await typeInto(tester, 'Adventure name', 'Bangkok squad trip');
    await tapText(tester, 'Next');
    await tapText(tester, 'Choose dates');
    await tapOn(tester, find.byIcon(Icons.edit_outlined));
    final today = DateTime.now();
    await tester.enterText(find.byType(TextField).at(0), usDate(today));
    await tester.enterText(
      find.byType(TextField).at(1),
      usDate(today.add(const Duration(days: 7))),
    );
    await tapText(tester, 'OK');
    await tapText(tester, 'Create adventure');
    await waitFor(tester, find.textContaining('Trip currency: THB'));
    await waitFor(tester, find.text('Squad (1)'));

    final adventures = await listDocs('adventures');
    final adventure = adventures.singleWhere(
      (a) => a['name'] == 'Bangkok squad trip',
    );
    final aid = adventure['id']! as String;
    expect(adventure['leaderUid'], uid);
    expect(adventure['baseCurrency'], 'THB');

    // Share the invite: the share sheet gets the link and the code.
    await scrollTo(tester, find.text('Share invite'));
    await tapText(tester, 'Share invite');
    await waitFor(tester, find.text('Invite code'));
    expect(shared.texts, hasLength(1));
    final code = (await getDoc('adventures/$aid'))!['activeInviteCode']!;
    expect(shared.texts.single, contains('/i/$code'));

    // Bob joins with the code on his own phone.
    final bob = await createPerson('Bob Joiner');
    await call('joinAdventure', {'code': code}, as: bob);

    // Ari gets a join card and promotes Bob from it.
    await tester.pageBack();
    await waitFor(tester, find.text('Bob Joiner joined your squad'));
    await tapText(tester, 'Make co-lead');
    await waitFor(tester, find.text('Bob Joiner is now a co-lead.'));
    await eventually(
      'Bob is a co-lead',
      () async => ((await getDoc('adventures/$aid'))!['coLeadUids']! as List)
          .contains(bob.uid),
    );

    // Add a pal (no account) to the squad.
    await openAdventure(tester, 'Bangkok squad trip');
    await waitFor(tester, find.text('Squad (2)'));
    await scrollTo(tester, find.text('Add pal'));
    await tapText(tester, 'Add pal');
    await tester.enterText(find.byType(TextField).last, 'Kiko');
    await tapOn(tester, find.widgetWithText(FilledButton, 'Add'));
    await waitFor(tester, find.text('Squad (3)'));
    expect(find.text('Pal'), findsOneWidget);
    expect(find.text('Co-lead'), findsOneWidget);
    final pals = await listDocs('adventures/$aid/pals', as: bob);
    expect(pals.map((p) => p['nickname']), ['Kiko']);

    await signOut(tester);
  });
}
