import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/driver.dart';
import '../support/emulators.dart';

/// Journey B – Invitee (spec §15.2): open the invite link → sign up →
/// accept the invite → see the squad. Installing the APK from the link is
/// a manual check; here the invitee pastes the link into "Have an invite
/// code?", which goes through the same lookup and join.
void journeyB() {
  testWidgets('Journey B: an invitee joins from a link', (tester) async {
    final dan = await createPerson('Dan Leader');
    final aid = await seedAdventure(dan, name: 'Goa getaway');
    final invite = await call('createInvite', {'adventureId': aid}, as: dan);
    final link = 'https://roamio.app/i/${invite['code']}';

    await launch(tester);
    final email = uniqueEmail('cara');
    final uid = await signUpWithEmail(
      tester,
      name: 'Cara Invitee',
      email: email,
      dob: DateTime(1999, 2, 3),
    );
    await waitFor(tester, find.text('Hey Cara 👋'));

    // Paste the link, find the invite, join.
    await tapText(tester, 'Have an invite code?');
    await typeInto(tester, 'Code or invite link', link);
    await tapText(tester, 'Find invite');
    await waitFor(tester, find.text('🇮🇳  Goa getaway'));
    expect(find.textContaining('From Dan'), findsOneWidget);
    await tapOn(tester, find.widgetWithText(FilledButton, 'Join squad'));
    await waitForGone(tester, find.text('Join squad'));

    // The adventure is on Home; the squad shows both, with their roles.
    await openAdventure(tester, 'Goa getaway');
    await waitFor(tester, find.text('Squad (2)'));
    await waitFor(tester, find.text('Cara Invitee (you)'));
    await waitFor(tester, find.text('Dan Leader'));
    expect(find.text('Squad leader'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);

    // The server has her as a member, and the leader got a join card.
    final adventure = (await getDoc('adventures/$aid', as: dan))!;
    expect(adventure['memberUids'], containsAll([dan.uid, uid]));
    expect(
      await getDoc('users/${dan.uid}/notifications/${aid}_joined_$uid'),
      isNotNull,
    );

    await signOut(tester);
  });
}
