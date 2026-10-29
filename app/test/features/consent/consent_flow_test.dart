import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/consent/data/consent_service.dart';

import '../../support/fake_auth_service.dart';
import '../../support/fake_consent_service.dart';

const _pendingTeen = SessionFacts(
  uid: 'mia',
  hasAccount: true,
  ageStatus: 'minor_pending',
);

void _go(WidgetTester tester, String location) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);

void main() {
  group('teen asks a parent (spec §7.1 steps 2–3)', () {
    testWidgets('validates the email, then sends with the relationship', (
      tester,
    ) async {
      final consent = FakeConsentService();
      await pumpRoamio(
        tester,
        FakeAuthService(initial: _pendingTeen),
        consent: consent,
      );

      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(consent.calls, isEmpty);

      await tester.enterText(find.byType(TextFormField), 'pat@example.com');
      await tester.tap(find.text('Father'));
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();

      expect(consent.calls, ['request:pat@example.com:father']);
      expect(find.text('Waiting for a yes ⏳'), findsOneWidget);
      expect(find.textContaining('pat@example.com'), findsOneWidget);
    });

    testWidgets('waiting: resend, change email, and limits explained', (
      tester,
    ) async {
      final consent = FakeConsentService()
        ..request = const MyConsentRequest(
          parentEmail: 'pat@example.com',
          status: 'requested',
        );
      await pumpRoamio(
        tester,
        FakeAuthService(initial: _pendingTeen),
        consent: consent,
      );
      expect(find.byType(PrimaryButton), findsOneWidget);

      await tester.tap(find.text('Send the email again'));
      await tester.pumpAndSettle();
      expect(consent.calls, ['request:pat@example.com:mother']);

      consent.failNext = 'You can send 3 requests a day. Try tomorrow.';
      await tester.tap(find.text('Send the email again'));
      await tester.pumpAndSettle();
      expect(
        find.text('You can send 3 requests a day. Try tomorrow.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Use a different email'));
      await tester.pumpAndSettle();
      expect(find.text('Send request'), findsOneWidget);
    });
  });

  testWidgets('a withdrawn minor sees their account is paused', (tester) async {
    await pumpRoamio(
      tester,
      FakeAuthService(
        initial: const SessionFacts(
          uid: 'mia',
          hasAccount: true,
          ageStatus: 'minor_frozen',
        ),
      ),
    );
    expect(find.text('Your account is paused'), findsOneWidget);
  });

  testWidgets('turning 18: accept the adult notice to carry on (spec §7.4)', (
    tester,
  ) async {
    final consent = FakeConsentService();
    await pumpRoamio(
      tester,
      FakeAuthService(
        initial: const SessionFacts(
          uid: 'mia',
          hasAccount: true,
          ageStatus: 'adult_unconfirmed',
        ),
      ),
      consent: consent,
    );
    expect(find.text('Happy 18th! 🎂'), findsOneWidget);
    await tester.tap(find.text('Accept and continue'));
    await tester.pumpAndSettle();
    expect(consent.calls, ['acceptAdult']);
  });

  group('parent decides (spec §7.1 steps 4–7)', () {
    const link = '/consent?c=mia&t=tok123';

    testWidgets('a link opened before signing in opens after sign-in', (
      tester,
    ) async {
      final auth = FakeAuthService();
      final consent = FakeConsentService();
      await pumpRoamio(tester, auth, consent: consent);

      _go(tester, link);
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);

      auth.emit(readyFacts);
      await tester.pumpAndSettle();
      expect(find.text('Mia wants to use Roamio'), findsOneWidget);
      expect(consent.calls, ['describe:mia:tok123']);
    });

    testWidgets('consent needs the guardian declaration, then is recorded', (
      tester,
    ) async {
      final consent = FakeConsentService();
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        consent: consent,
      );
      _go(tester, link);
      await tester.pumpAndSettle();

      await tester.tap(find.text('I give consent'));
      await tester.pumpAndSettle();
      expect(consent.calls, ['describe:mia:tok123']);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('I give consent'));
      await tester.pumpAndSettle();
      expect(consent.calls.last, 'grant:mia');
      expect(find.text('All set 🎉'), findsOneWidget);
    });

    testWidgets('declining asks to confirm first', (tester) async {
      final consent = FakeConsentService();
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        consent: consent,
      );
      _go(tester, link);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
      expect(consent.calls, ['describe:mia:tok123']);

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Decline').last);
      await tester.pumpAndSettle();
      expect(consent.calls.last, 'decline:mia');
      expect(find.textContaining('deleted Mia’s account'), findsOneWidget);
    });

    testWidgets('an expired or replaced link says why and offers a way on', (
      tester,
    ) async {
      final consent = FakeConsentService()..details = null;
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        consent: consent,
      );
      _go(tester, link);
      await tester.pumpAndSettle();

      expect(find.text('This link can’t be used'), findsOneWidget);
      expect(find.text('This request has expired.'), findsOneWidget);
      await tester.tap(find.text('Go to Roamio'));
      await tester.pumpAndSettle();
      expect(find.text('Hey Ari 👋'), findsOneWidget);
    });
  });

  group('linked children (spec §7.3)', () {
    Future<FakeConsentService> openYou(WidgetTester tester) async {
      final consent = FakeConsentService()
        ..children = [
          LinkedChild(
            uid: 'mia',
            name: 'Mia Rao',
            since: DateTime(2026, 10, 29),
          ),
        ];
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        consent: consent,
      );
      await tester.tap(find.text('You'));
      await tester.pumpAndSettle();
      return consent;
    }

    testWidgets('lists children and withdraws only after confirming', (
      tester,
    ) async {
      final consent = await openYou(tester);
      await tester.scrollUntilVisible(
        find.text('Withdraw'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Mia Rao'), findsOneWidget);
      expect(find.text('Consent given 29 Oct 2026'), findsOneWidget);

      await tester.ensureVisible(find.text('Withdraw'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep consent'));
      await tester.pumpAndSettle();
      expect(consent.calls, isEmpty);

      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdraw').last);
      await tester.pumpAndSettle();
      expect(consent.calls, ['withdraw:mia']);
    });

    testWidgets('signing out is always available', (tester) async {
      final auth = FakeAuthService(initial: readyFacts);
      await pumpRoamio(tester, auth);
      await tester.tap(find.text('You'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Sign out'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      expect(auth.calls, ['signOut']);
    });
  });
}
