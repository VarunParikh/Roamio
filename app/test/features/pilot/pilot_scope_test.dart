import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/consent/data/consent_service.dart';

import '../../support/fake_auth_service.dart';
import '../../support/fake_consent_service.dart';

/// The Android pilot is for adults only: under-18 accounts, parental
/// consent and nominating a person come back in Phase 2 with the web app
/// (owner, 2026-10-30). Their code stays; these switches hide them.
void main() {
  const tick = 'I’m 18 or older and I’ve read the ';

  testWidgets('email sign-up asks no birth date; the 18+ tick is recorded', (
    tester,
  ) async {
    final auth = FakeAuthService();
    await pumpRoamio(tester, auth, phase2: false);
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Date of birth'), findsNothing);
    expect(find.text(tick), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your name'),
      'Ari',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'ari@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret123',
    );
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    // Without the tick nothing happens, with a reason.
    expect(
      find.text(
        'Please confirm you’re 18 or older and accept the privacy '
        'notice.',
      ),
      findsOneWidget,
    );
    expect(auth.calls, isEmpty);

    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(auth.calls, ['create:Ari:ari@example.com:adult']);
  });

  testWidgets('a Google sign-in just confirms 18+ and the notice', (
    tester,
  ) async {
    final auth = FakeAuthService(initial: const SessionFacts(uid: 'u'));
    await pumpRoamio(tester, auth, phase2: false);

    expect(find.text('Date of birth'), findsNothing);
    expect(find.textContaining('under-18'), findsNothing);
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(auth.calls, ['complete:adult']);
  });

  testWidgets('no Linked children on You, and no child downloads or '
      'nominee in the Privacy centre', (tester) async {
    await pumpRoamio(
      tester,
      FakeAuthService(initial: readyFacts),
      phase2: false,
      consent: FakeConsentService()
        ..children = [const LinkedChild(uid: 'mia', name: 'Mia', since: null)],
    );
    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Privacy centre'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Linked children', skipOffstage: false), findsNothing);

    await tester.tap(find.text('Privacy centre'));
    await tester.pumpAndSettle();
    final list = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Delete my account'),
      300,
      scrollable: list,
    );
    expect(find.text('Nominate a person', skipOffstage: false), findsNothing);
    expect(find.text('Download Mia’s data', skipOffstage: false), findsNothing);
    expect(find.text('Linked children', skipOffstage: false), findsNothing);
  });
}
