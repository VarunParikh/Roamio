import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The signed-in person's private profile settings (spec UC-28).
abstract interface class ProfileService {
  /// The currency they see amounts in (spec UC-26).
  Stream<String> profileCurrency();
}

/// Overridden in tests; reads the signed-in person's account otherwise.
final profileServiceProvider = Provider<ProfileService>(
  (ref) =>
      FirebaseProfileService(FirebaseAuth.instance, FirebaseFirestore.instance),
);

final profileCurrencyProvider = StreamProvider<String>(
  (ref) => ref.watch(profileServiceProvider).profileCurrency(),
);

class FirebaseProfileService implements ProfileService {
  new(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  Stream<String> profileCurrency() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value('INR');
    return _db
        .doc('users/$uid/private/account')
        .snapshots()
        .map((s) => (s.data()?['profileCurrency'] as String?) ?? 'INR');
  }
}
