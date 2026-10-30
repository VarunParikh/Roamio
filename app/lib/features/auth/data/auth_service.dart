import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/features/auth/data/firebase_auth_service.dart'
    show FirebaseAuthService;
import 'package:roamio/features/auth/domain/session.dart';

/// Version of the privacy notice a person accepts at sign-up (spec §8).
const privacyNoticeVersion = '2026-10';

/// Why a sign-in action failed, worded for the person using the app.
enum AuthFailure {
  wrongCredentials('That email and password don’t match.'),
  emailInUse('There’s already an account with that email. Try signing in.'),
  weakPassword('Pick a stronger password: at least 8 characters.'),
  invalidEmail('That email address doesn’t look right.'),
  tooManyRequests('Too many tries. Wait a minute and try again.'),
  network('No connection. Check your internet and try again.'),
  cancelled('Sign-in was cancelled.'),
  unknown('Something went wrong. Please try again.');

  new(this.message);

  final String message;
}

class AuthException implements Exception {
  new(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'AuthException(${failure.name})';
}

/// Everything the sign-in screens need; [FirebaseAuthService] implements it,
/// and widget tests use a fake.
abstract interface class AuthService {
  /// Emits whenever the person, their email verification or their account
  /// record changes.
  Stream<SessionFacts> session();

  String? get email;
  String? get displayName;

  Future<void> signInWithGoogle();
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });
  Future<void> sendPasswordReset(String email);

  /// Creates an email account plus its profile and account records, then
  /// sends the verification email. A null [dob] means the person ticked
  /// "I'm 18 or older" instead (the pilot asks no birth date; Phase 2 does).
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
    required DateTime? dob,
  });

  /// Writes the account record for someone who signed in with Google; a
  /// null [dob] means they declared they're 18 or older.
  Future<void> completeProfile({required DateTime? dob});

  Future<void> sendVerificationEmail();

  /// Re-reads the signed-in user after they verify their email; returns
  /// whether the email is now verified.
  Future<bool> refreshUser();

  Future<void> signOut();

  /// Deletes the signed-in auth user (used for under-13 Google sign-ups).
  Future<void> deleteCurrentUser();
}

/// Overridden in `main.dart` with the Firebase implementation.
final authServiceProvider = Provider<AuthService>(
  (ref) => throw UnimplementedError('authServiceProvider must be overridden'),
);

final sessionFactsProvider = StreamProvider<SessionFacts>(
  (ref) => ref.watch(authServiceProvider).session(),
);

final sessionStageProvider = Provider<AsyncValue<SessionStage>>(
  (ref) => ref.watch(sessionFactsProvider).whenData(stageFor),
);

/// Today's date; overridden in tests so age checks are deterministic.
final todayProvider = Provider<DateTime>((ref) => DateTime.now());
