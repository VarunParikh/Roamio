import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/driver.dart';
import '../support/emulators.dart';

/// Journey E – Minor (spec §15.5, §7): a 16-year-old signs up → a parent
/// consents through the emailed link → the child joins an adventure;
/// location tagging is unavailable. The decline path deletes the account.
///
/// The parent is simulated: the test reads the queued email (the `mail`
/// outbox) for the link's token and calls `decideParentalConsent` as the
/// parent, as the consent screen does.
void journeyE() {
  testWidgets('Journey E: a minor gets consent, joins, and has no location', (
    tester,
  ) async {
    final pat = await createPerson('Pat Parent');
    final dan = await createPerson('Dan Leader');
    final aid = await seedAdventure(dan, name: 'School trip Jaipur');
    final invite = await call('createInvite', {'adventureId': aid}, as: dan);

    await launch(tester);
    final email = uniqueEmail('mia');
    final now = DateTime.now();
    final uid = await signUpWithEmail(
      tester,
      name: 'Mia Minor',
      email: email,
      dob: DateTime(now.year - 16, now.month),
    );

    // Under 18: ask a parent.
    await waitFor(tester, find.text('Almost there! 🙌'));
    expect(
      (await getDoc('users/$uid/private/account'))!['ageStatus'],
      'minor_pending',
    );
    await typeInto(tester, 'Their email address', pat.email);
    await tapText(tester, 'Mother');
    await tapText(tester, 'Send request');
    await waitFor(tester, find.text('Waiting for a yes ⏳'));

    // The parent opens the emailed link and says yes.
    final link = await _consentLink(pat.email);
    expect(link.childUid, uid);
    final described = await call('describeConsentRequest', {
      'childUid': uid,
      'token': link.token,
    }, as: pat);
    expect(described['childFirstName'], 'Mia');
    await call('decideParentalConsent', {
      'childUid': uid,
      'token': link.token,
      'decision': 'grant',
    }, as: pat);

    // Mia is in, and joins the squad with an invite code.
    await waitFor(tester, find.text('Hey Mia 👋'));
    final consent = (await getDoc('parentalConsents/$uid'))!;
    expect(consent['status'], 'granted');
    expect(consent['parentUid'], pat.uid);
    await tapText(tester, 'Have an invite code?');
    await typeInto(tester, 'Code or invite link', invite['code']! as String);
    await tapText(tester, 'Find invite');
    await tapOn(tester, find.widgetWithText(FilledButton, 'Join squad'));
    await waitForGone(tester, find.text('Join squad'));
    await openAdventure(tester, 'School trip Jaipur');
    await waitFor(tester, find.text('Squad (2)'));

    // No location on a new tab: not even the "turn it on" hint.
    await scrollTo(tester, find.text('Add tab'));
    await tapText(tester, 'Add tab');
    await scrollTo(tester, find.text('Paid by'));
    expect(find.text('Add location'), findsNothing);
    expect(find.textContaining('Location is off'), findsNothing);
    await tester.pageBack();
    await settle(tester);
    await tester.pageBack();
    await settle(tester);

    // You says why, and the switch is off.
    await tapText(tester, 'You');
    await scrollTo(
      tester,
      find.text('Location is always off for under-18 accounts.'),
    );

    // The rules refuse a location from a minor even without the app.
    final child = Person(uid, email, 'Mia Minor', '');
    await child.refresh();
    final point = {'lat': 26.9124, 'lng': 75.7873};
    final people = [dan.uid, uid];
    expect(
      await createDocAs(
        child,
        'adventures/$aid/tabs',
        tabDoc(
          createdBy: uid,
          amountMinor: 50000,
          participants: people,
          location: point,
        ),
      ),
      403,
    );
    expect(
      await createDocAs(
        child,
        'adventures/$aid/tabs',
        tabDoc(createdBy: uid, amountMinor: 50000, participants: people),
      ),
      200,
    );

    await signOut(tester);
  });

  testWidgets('Journey E: a declined minor’s account is deleted', (
    tester,
  ) async {
    final pat = await createPerson('Pat Parent');
    await launch(tester);
    final email = uniqueEmail('leo');
    final now = DateTime.now();
    final uid = await signUpWithEmail(
      tester,
      name: 'Leo Minor',
      email: email,
      dob: DateTime(now.year - 15, now.month),
    );
    await waitFor(tester, find.text('Almost there! 🙌'));
    await typeInto(tester, 'Their email address', pat.email);
    await tapText(tester, 'Send request');
    await waitFor(tester, find.text('Waiting for a yes ⏳'));

    final link = await _consentLink(pat.email);
    await call('decideParentalConsent', {
      'childUid': uid,
      'token': link.token,
      'decision': 'decline',
    }, as: pat);

    // The account and its data are gone, and Leo is told by email.
    await eventually(
      'Leo’s sign-in is deleted',
      () async => await uidForEmail(email) == null,
    );
    expect(await getDoc('users/$uid'), isNull);
    expect(await getDoc('users/$uid/private/account'), isNull);
    expect((await getDoc('parentalConsents/$uid'))!['status'], 'declined');
    final mail = await listDocs('mail');
    expect(
      mail.where(
        (m) =>
            m['to'] == email &&
            ((m['message']! as Map)['subject']! as String).contains('closed'),
      ),
      hasLength(1),
    );

    // Leo's phone leaves the waiting screen for the sign-in screen.
    await waitFor(
      tester,
      find.text('Continue with Google'),
      timeout: const Duration(seconds: 60),
    );
  });
}

typedef _Link = ({String childUid, String token});

/// The consent link from the newest email to [parentEmail].
Future<_Link> _consentLink(String parentEmail) async {
  late RegExpMatch match;
  await eventually('a consent email to $parentEmail', () async {
    for (final m in await listDocs('mail')) {
      if (m['to'] != parentEmail) continue;
      final text = (m['message']! as Map)['text']! as String;
      final found = RegExp(r'/consent\?c=([^&\s]+)&t=(\S+)').firstMatch(text);
      if (found != null) {
        match = found;
        return true;
      }
    }
    return false;
  });
  return (childUid: Uri.decodeComponent(match[1]!), token: match[2]!);
}
