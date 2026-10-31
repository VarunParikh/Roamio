import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/auth/ui/google_logo.dart';
import 'package:roamio/features/auth/ui/verify_email_screen.dart';

import '../../../support/fake_auth_service.dart';

void main() {
  group('routing by session stage (UC-1)', () {
    final cases = <String, (SessionFacts, String)>{
      'signed out → sign in': (
        const SessionFacts.signedOut(),
        'Continue with Google',
      ),
      'unverified email → check inbox': (
        const SessionFacts(uid: 'u', usesPassword: true, emailVerified: false),
        'Check your inbox 📬',
      ),
      'Google user without DOB → one last thing': (
        const SessionFacts(uid: 'u'),
        'One last thing, Ari',
      ),
      'waiting for the server → splash': (
        const SessionFacts(uid: 'u', hasAccount: true),
        'Setting up your account…',
      ),
      '13–17 → waiting for a parent': (
        const SessionFacts(
          uid: 'u',
          hasAccount: true,
          ageStatus: 'minor_pending',
        ),
        'Almost there! 🙌',
      ),
      'adult → home': (readyFacts, 'Hey Ari 👋'),
    };

    for (final MapEntry(key: name, value: (facts, expected)) in cases.entries) {
      testWidgets(name, (tester) async {
        final onSplash = stageFor(facts) == SessionStage.settingUp;
        await pumpRoamio(
          tester,
          FakeAuthService(initial: facts),
          settle: !onSplash,
        );
        expect(find.text(expected), findsOneWidget);
      });
    }

    testWidgets('moves on by itself when the stage changes', (tester) async {
      final auth = FakeAuthService(
        initial: const SessionFacts(uid: 'u', hasAccount: true),
      );
      await pumpRoamio(tester, auth, settle: false);
      expect(find.text('Setting up your account…'), findsOneWidget);

      auth.emit(readyFacts);
      await tester.pumpAndSettle();
      expect(find.text('Hey Ari 👋'), findsOneWidget);
    });

    testWidgets('signing out from anywhere returns to sign in', (tester) async {
      final auth = FakeAuthService(initial: readyFacts);
      await pumpRoamio(tester, auth);

      auth.emit(const SessionFacts.signedOut());
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });

  group('sign in (UC-2)', () {
    testWidgets('Google has its own logo and white button', (tester) async {
      await pumpRoamio(tester, FakeAuthService());
      expect(find.byType(GoogleLogo), findsOneWidget);
      expect(
        find.widgetWithText(PrimaryButton, 'Continue with Google'),
        findsNothing,
      );
    });

    testWidgets('Google errors are explained; a cancel is silent', (
      tester,
    ) async {
      final auth = FakeAuthService()..failNext = AuthFailure.network;
      await pumpRoamio(tester, auth);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text(AuthFailure.network.message), findsOneWidget);

      auth.failNext = AuthFailure.cancelled;
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text(AuthFailure.cancelled.message), findsNothing);
      expect(auth.calls, ['google', 'google']);
    });

    testWidgets('email sign-in validates, then signs in', (tester) async {
      final auth = FakeAuthService();
      await pumpRoamio(tester, auth);
      await tester.tap(find.text('Sign in with email'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(auth.calls, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        ' ari@example.com ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret123',
      );
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(auth.calls, ['email:ari@example.com']);
    });

    testWidgets('forgot password needs the email first, then sends a link', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await pumpRoamio(tester, auth);
      await tester.tap(find.text('Sign in with email'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email above first.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'ari@example.com',
      );
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(auth.calls, ['reset:ari@example.com']);
      expect(find.text('Check your inbox for a reset link.'), findsOneWidget);
    });
  });

  group('create account (UC-3, UC-4)', () {
    Future<void> openSignup(WidgetTester tester, FakeAuthService auth) async {
      await pumpRoamio(tester, auth);
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
    }

    Future<void> pickDob(WidgetTester tester, String typed) async {
      await tester.tap(find.text('Choose a date'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, typed);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    Future<void> fillValid(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Your name'),
        ' Ari Chen ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'ari@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret123',
      );
    }

    testWidgets('shows every problem and creates nothing', (tester) async {
      final auth = FakeAuthService();
      await openSignup(tester, auth);

      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Tell us what to call you.'), findsOneWidget);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(find.text('Add your date of birth.'), findsOneWidget);
      expect(
        find.text('Please read and accept the privacy notice.'),
        findsOneWidget,
      );
      expect(auth.calls, isEmpty);
    });

    testWidgets('refuses under-13s before any account exists', (tester) async {
      final auth = FakeAuthService();
      await openSignup(tester, auth);
      await fillValid(tester);
      await pickDob(tester, '10/30/2013'); // turns 13 tomorrow
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(
        find.text('Roamio is for people aged 13 and over.'),
        findsOneWidget,
      );
      expect(auth.calls, isEmpty);
    });

    testWidgets('creates the account with trimmed details', (tester) async {
      final auth = FakeAuthService();
      await openSignup(tester, auth);
      await fillValid(tester);
      await pickDob(tester, '10/29/2010'); // 16 today: a minor is allowed
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(auth.calls, ['create:Ari Chen:ari@example.com:2010-10-29']);
    });

    testWidgets('explains an email that is already taken', (tester) async {
      final auth = FakeAuthService()..failNext = AuthFailure.emailInUse;
      await openSignup(tester, auth);
      await fillValid(tester);
      await pickDob(tester, '01/01/2000');
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(find.text(AuthFailure.emailInUse.message), findsOneWidget);
    });

    testWidgets('the privacy notice summary opens from the link', (
      tester,
    ) async {
      await openSignup(tester, FakeAuthService());
      await tester.tap(find.text('privacy notice'));
      await tester.pumpAndSettle();
      expect(find.textContaining('stored in India'), findsOneWidget);
    });
  });

  group('complete profile for Google sign-ups', () {
    Future<FakeAuthService> open(WidgetTester tester) async {
      final auth = FakeAuthService(initial: const SessionFacts(uid: 'u'));
      await pumpRoamio(tester, auth);
      return auth;
    }

    Future<void> submitWithDob(WidgetTester tester, String typed) async {
      await tester.tap(find.text('Choose a date'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, typed);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    testWidgets('saves the date of birth', (tester) async {
      final auth = await open(tester);
      await submitWithDob(tester, '05/01/1999');
      expect(auth.calls, ['complete:1999-5-1']);
    });

    testWidgets('removes an under-13 Google sign-in and signs out', (
      tester,
    ) async {
      final auth = await open(tester);
      await submitWithDob(tester, '01/01/2015');
      expect(auth.calls, ['delete', 'signOut']);
      expect(
        find.text('Sorry, Roamio is for people aged 13 and over.'),
        findsOneWidget,
      );
    });
  });

  group('verify email (UC-2)', () {
    const unverified = SessionFacts(
      uid: 'u',
      usesPassword: true,
      emailVerified: false,
    );

    testWidgets('resend waits 60 seconds, then works', (tester) async {
      final auth = FakeAuthService(initial: unverified);
      await pumpRoamio(tester, auth);

      expect(find.text('Resend email in ${resendCooldown}s'), findsOneWidget);
      await tester.tap(find.text('Resend email in ${resendCooldown}s'));
      expect(auth.calls, isEmpty);

      await tester.pump(const Duration(seconds: resendCooldown));
      await tester.tap(find.text('Resend email'));
      await tester.pump();
      expect(auth.calls, ['resend']);
      expect(find.text('Resend email in ${resendCooldown}s'), findsOneWidget);
    });

    testWidgets('says so when the email is not verified yet', (tester) async {
      final auth = FakeAuthService(initial: unverified);
      await pumpRoamio(tester, auth);

      await tester.tap(find.text('I’ve verified my email'));
      await tester.pumpAndSettle();
      expect(
        find.text('Not verified yet. Tap the link in the email first.'),
        findsOneWidget,
      );
    });

    testWidgets('a different account signs out', (tester) async {
      final auth = FakeAuthService(initial: unverified);
      await pumpRoamio(tester, auth);
      await tester.tap(find.text('Use a different account'));
      expect(auth.calls, ['signOut']);
    });
  });
}
