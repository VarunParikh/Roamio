import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/age.dart';
import 'package:roamio/features/auth/domain/session.dart';

/// Codes Firebase Auth gives when the server has deleted or shut a sign-in.
const _goneCodes = {'user-not-found', 'user-disabled', 'user-token-expired'};

/// When someone's account record is missing, checks their sign-in still
/// exists and signs out if the server deleted it (a parent declined, or the
/// account was erased), so the phone doesn't ask them to set up a profile
/// again. A new sign-up without a record yet, or a failed check, stays.
/// Returns whether it signed out.
Future<bool> signOutIfDeleted({
  required Future<void> Function() reload,
  required Future<void> Function() signOut,
}) async {
  try {
    await reload();
    return false;
  } on FirebaseAuthException catch (e) {
    if (!_goneCodes.contains(e.code)) return false;
    await signOut();
    return true;
  }
}

/// Decides when a missing account record is worth checking: once each
/// time it goes missing. Checking reloads the user, which fires another
/// user event and re-reads the record, so without this a new sign-up with
/// no record yet would reload in a loop.
class MissingAccountCheck {
  final _checked = <String>{};

  bool shouldCheck(String uid, {required bool exists}) {
    if (exists) {
      _checked.remove(uid);
      return false;
    }
    return _checked.add(uid);
  }
}

class FirebaseAuthService implements AuthService {
  new(this._auth, this._db, this._google);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _google;
  final _missing = MissingAccountCheck();
  bool _googleReady = false;

  DocumentReference<Map<String, dynamic>> _account(String uid) =>
      _db.doc('users/$uid/private/account');

  @override
  Stream<SessionFacts> session() {
    // Switch to the newest user's account-record stream on every auth change.
    late final StreamController<SessionFacts> out;
    StreamSubscription<User?>? users;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? account;

    void follow(User? user) {
      unawaited(account?.cancel());
      account = null;
      if (user == null) {
        out.add(const SessionFacts.signedOut());
        return;
      }
      final usesPassword = user.providerData.any(
        (p) => p.providerId == 'password',
      );
      SessionFacts facts({bool loaded = false, DocumentSnapshot? snap}) =>
          SessionFacts(
            uid: user.uid,
            usesPassword: usesPassword,
            emailVerified: user.emailVerified,
            accountLoaded: loaded,
            hasAccount: snap?.exists ?? false,
            ageStatus: snap?.exists ?? false
                ? (snap!.data()! as Map<String, dynamic>)['ageStatus']
                      as String?
                : null,
          );
      out.add(facts());
      account = _account(user.uid).snapshots().listen((snap) {
        out.add(facts(loaded: true, snap: snap));
        if (_missing.shouldCheck(user.uid, exists: snap.exists)) {
          unawaited(signOutIfDeleted(reload: user.reload, signOut: signOut));
        }
      }, onError: (Object _) => out.add(facts(loaded: true)));
    }

    out = StreamController<SessionFacts>(
      onListen: () => users = _auth.userChanges().listen(follow),
      onCancel: () async {
        await account?.cancel();
        await users?.cancel();
      },
    );
    return out.stream;
  }

  @override
  String? get email => _auth.currentUser?.email;

  @override
  String? get displayName => _auth.currentUser?.displayName;

  @override
  Future<void> signInWithGoogle() => _guard(() async {
    if (!_googleReady) {
      await _google.initialize();
      _googleReady = true;
    }
    final account = await _google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) throw AuthException(AuthFailure.unknown);
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  });

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _guard(
    () => _auth.signInWithEmailAndPassword(email: email, password: password),
  );

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email));

  @override
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
    required DateTime? dob,
  }) => _guard(() async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(name);
    await _writeRecords(user.uid, name: name, photoUrl: null, dob: dob);
    await user.sendEmailVerification();
  });

  @override
  Future<void> completeProfile({required DateTime? dob}) => _guard(() async {
    final user = _auth.currentUser!;
    final name = (user.displayName ?? '').trim();
    await _writeRecords(
      user.uid,
      name: name.isEmpty
          ? 'Traveller'
          : name.substring(0, name.length.clamp(0, 60)),
      photoUrl: user.photoURL,
      dob: dob,
    );
  });

  /// The public profile and the private account record (DATA_MODEL.md).
  /// The server then sets `ageStatus` from [dob], or to adult when the
  /// person declared they're 18 or older (no [dob]).
  Future<void> _writeRecords(
    String uid, {
    required String name,
    required String? photoUrl,
    required DateTime? dob,
  }) async {
    await _db.doc('users/$uid').set({
      'name': name,
      'photoUrl': photoUrl,
      'bio': '',
    });
    await _account(uid).set({
      if (dob != null) 'dob': isoDate(dob) else 'adultDeclared': true,
      'profileCurrency': 'INR',
      'consents': <String, bool>{},
      'noticeVersion': privacyNoticeVersion,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> sendVerificationEmail() =>
      _guard(() => _auth.currentUser!.sendEmailVerification());

  @override
  Future<bool> refreshUser() => _guard(() async {
    await _auth.currentUser!.reload();
    return _auth.currentUser?.emailVerified ?? false;
  });

  @override
  Future<void> signOut() async {
    if (_googleReady) await _google.signOut();
    await _auth.signOut();
  }

  @override
  Future<void> deleteCurrentUser() => _guard(() => _auth.currentUser!.delete());

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_failureFor(e.code));
    } on GoogleSignInException catch (e) {
      throw AuthException(
        e.code == GoogleSignInExceptionCode.canceled
            ? AuthFailure.cancelled
            : AuthFailure.unknown,
      );
    } on FirebaseException catch (e) {
      throw AuthException(
        e.code == 'unavailable' ? AuthFailure.network : AuthFailure.unknown,
      );
    }
  }

  static AuthFailure _failureFor(String code) => switch (code) {
    'wrong-password' ||
    'user-not-found' ||
    'invalid-credential' ||
    'invalid-login-credentials' => AuthFailure.wrongCredentials,
    'email-already-in-use' => AuthFailure.emailInUse,
    'weak-password' => AuthFailure.weakPassword,
    'invalid-email' => AuthFailure.invalidEmail,
    'too-many-requests' => AuthFailure.tooManyRequests,
    'network-request-failed' => AuthFailure.network,
    _ => AuthFailure.unknown,
  };
}
