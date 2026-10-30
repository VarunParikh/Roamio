import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/auth/data/firebase_auth_service.dart';

/// Found by Journey E (Task 41): when a parent declines, the server deletes
/// the child's sign-in and records, but the phone kept its session and asked
/// the child to "complete" a profile again. A missing account record now
/// checks the sign-in still exists, and signs out if it doesn't.
void main() {
  group('signOutIfDeleted', () {
    test('signs out when the server has deleted the sign-in', () async {
      var signedOut = 0;
      final gone = await signOutIfDeleted(
        reload: () async => throw FirebaseAuthException(code: 'user-not-found'),
        signOut: () async => signedOut++,
      );
      expect(gone, isTrue);
      expect(signedOut, 1);
    });

    test('also for a disabled account or a revoked session', () async {
      for (final code in ['user-disabled', 'user-token-expired']) {
        var signedOut = 0;
        await signOutIfDeleted(
          reload: () async => throw FirebaseAuthException(code: code),
          signOut: () async => signedOut++,
        );
        expect(signedOut, 1, reason: code);
      }
    });

    test('keeps a new sign-up that has no record yet', () async {
      var signedOut = 0;
      final gone = await signOutIfDeleted(
        reload: () async {},
        signOut: () async => signedOut++,
      );
      expect(gone, isFalse);
      expect(signedOut, 0);
    });

    test('keeps the session when the check itself fails (offline)', () async {
      var signedOut = 0;
      final gone = await signOutIfDeleted(
        reload: () async =>
            throw FirebaseAuthException(code: 'network-request-failed'),
        signOut: () async => signedOut++,
      );
      expect(gone, isFalse);
      expect(signedOut, 0);
    });
  });

  group('MissingAccountCheck (follow-up C11)', () {
    test('checks once while the record is missing, not on every event', () {
      final check = MissingAccountCheck();
      expect(check.shouldCheck('ari', exists: false), isTrue);
      // reload() fires another user event, which re-reads the record.
      expect(check.shouldCheck('ari', exists: false), isFalse);
      expect(check.shouldCheck('ari', exists: false), isFalse);
    });

    test('checks again if the record comes back, then goes missing', () {
      final check = MissingAccountCheck();
      expect(check.shouldCheck('mia', exists: false), isTrue);
      expect(check.shouldCheck('mia', exists: true), isFalse);
      // The parent said no and the server deleted the account.
      expect(check.shouldCheck('mia', exists: false), isTrue);
    });

    test('each person separately', () {
      final check = MissingAccountCheck();
      expect(check.shouldCheck('ari', exists: false), isTrue);
      expect(check.shouldCheck('bob', exists: false), isTrue);
    });
  });
}
