import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/auth/domain/session.dart';

void main() {
  group('stageFor', () {
    test('loading until both auth and the account record are known', () {
      expect(stageFor(const SessionFacts.loading()), SessionStage.loading);
      expect(
        stageFor(const SessionFacts(uid: 'u', accountLoaded: false)),
        SessionStage.loading,
      );
    });

    test('signed out with no user', () {
      expect(stageFor(const SessionFacts.signedOut()), SessionStage.signedOut);
    });

    test('email sign-ups must verify before anything else (UC-2)', () {
      expect(
        stageFor(
          const SessionFacts(
            uid: 'u',
            usesPassword: true,
            emailVerified: false,
            hasAccount: true,
            ageStatus: 'adult',
          ),
        ),
        SessionStage.verifyEmail,
      );
    });

    test('Google users without an account record give their DOB once', () {
      expect(stageFor(const SessionFacts(uid: 'u')), SessionStage.needsProfile);
    });

    test('waits for the server to set the age status', () {
      expect(
        stageFor(const SessionFacts(uid: 'u', hasAccount: true)),
        SessionStage.settingUp,
      );
    });

    test(
      '13–17 wait for parental consent; adults and consented minors go in',
      () {
        expect(
          stageFor(
            const SessionFacts(
              uid: 'u',
              hasAccount: true,
              ageStatus: 'minor_pending',
            ),
          ),
          SessionStage.awaitingConsent,
        );
        for (final status in ['adult', 'minor_active']) {
          expect(
            stageFor(
              SessionFacts(uid: 'u', hasAccount: true, ageStatus: status),
            ),
            SessionStage.ready,
          );
        }
      },
    );
  });

  group('redirectFor', () {
    test('sends each stage to its screen', () {
      expect(redirectFor(SessionStage.loading, '/home'), '/splash');
      expect(redirectFor(SessionStage.settingUp, '/home'), '/splash');
      expect(redirectFor(SessionStage.signedOut, '/home'), '/login');
      expect(redirectFor(SessionStage.verifyEmail, '/home'), '/verify-email');
      expect(
        redirectFor(SessionStage.needsProfile, '/login'),
        '/complete-profile',
      );
      expect(
        redirectFor(SessionStage.awaitingConsent, '/home'),
        '/consent-pending',
      );
      expect(redirectFor(SessionStage.ready, '/login'), '/home');
      expect(redirectFor(SessionStage.ready, '/splash'), '/home');
    });

    test('leaves you where you are when that is allowed', () {
      expect(redirectFor(SessionStage.loading, '/splash'), isNull);
      expect(redirectFor(SessionStage.signedOut, '/login'), isNull);
      expect(redirectFor(SessionStage.signedOut, '/signup'), isNull);
      expect(redirectFor(SessionStage.signedOut, '/login/email'), isNull);
      expect(redirectFor(SessionStage.verifyEmail, '/verify-email'), isNull);
      expect(redirectFor(SessionStage.ready, '/split'), isNull);
      expect(redirectFor(SessionStage.ready, '/you'), isNull);
    });

    test('never lets an unfinished account reach the app', () {
      for (final stage in [
        SessionStage.signedOut,
        SessionStage.verifyEmail,
        SessionStage.needsProfile,
        SessionStage.settingUp,
        SessionStage.awaitingConsent,
      ]) {
        for (final tab in ['/home', '/split', '/you']) {
          expect(redirectFor(stage, tab), isNotNull, reason: '$stage at $tab');
        }
      }
    });
  });
}
