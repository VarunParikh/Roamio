import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// What the squad sees of a person (spec UC-28).
class Profile {
  const new({required this.name, this.bio = '', this.photoUrl});

  final String name;
  final String bio;
  final String? photoUrl;
}

/// Someone an adult names to use their privacy rights if they can't
/// (spec UC-29, DPDP §14).
@immutable
class Nominee {
  const new({required this.name, required this.email});

  final String name;
  final String email;

  @override
  bool operator ==(Object other) =>
      other is Nominee && other.name == name && other.email == email;

  @override
  int get hashCode => Object.hash(name, email);

  @override
  String toString() => 'Nominee($name, $email)';
}

/// The signed-in person's profile and private settings (spec UC-28).
abstract interface class ProfileService {
  /// The currency they see amounts in (spec UC-26).
  Stream<String> profileCurrency();

  Stream<Profile> profileStream();

  /// Saves name and description. Like tabs, it's queued when offline.
  Future<void> saveProfile({required String name, required String bio});

  Future<void> setProfileCurrency(String code);

  /// Whether they've allowed location (spec §7.2, §8). Under-18 accounts
  /// never get it, whatever is stored here.
  Stream<bool> locationAllowed();

  Future<void> setLocationAllowed({required bool allowed});

  /// Whether they let Roamio open the camera (spec §8); on until they turn
  /// it off. Choosing from the gallery works either way.
  Stream<bool> cameraAllowed();

  Future<void> setCameraAllowed({required bool allowed});

  /// Their nominee, or null when they haven't named one. Adults only.
  Stream<Nominee?> nomineeStream();

  /// Names, changes or (with null) removes their nominee.
  Future<void> setNominee(Nominee? nominee);
}

/// Overridden in tests; reads the signed-in person's account otherwise.
final profileServiceProvider = Provider<ProfileService>(
  (ref) =>
      FirebaseProfileService(FirebaseAuth.instance, FirebaseFirestore.instance),
);

final profileCurrencyProvider = StreamProvider<String>(
  (ref) => ref.watch(profileServiceProvider).profileCurrency(),
);

final profileStreamProvider = StreamProvider<Profile>(
  (ref) => ref.watch(profileServiceProvider).profileStream(),
);

final locationAllowedProvider = StreamProvider<bool>(
  (ref) => ref.watch(profileServiceProvider).locationAllowed(),
);

final cameraAllowedProvider = StreamProvider<bool>(
  (ref) => ref.watch(profileServiceProvider).cameraAllowed(),
);

final nomineeProvider = StreamProvider<Nominee?>(
  (ref) => ref.watch(profileServiceProvider).nomineeStream(),
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

  DocumentReference<Map<String, dynamic>>? get _profile {
    final uid = _auth.currentUser?.uid;
    return uid == null ? null : _db.doc('users/$uid');
  }

  DocumentReference<Map<String, dynamic>>? get _account {
    final uid = _auth.currentUser?.uid;
    return uid == null ? null : _db.doc('users/$uid/private/account');
  }

  @override
  Stream<Profile> profileStream() {
    final doc = _profile;
    if (doc == null) return const Stream.empty();
    return doc.snapshots().map((s) {
      final data = s.data();
      return Profile(
        name:
            (data?['name'] as String?) ?? _auth.currentUser?.displayName ?? '',
        bio: (data?['bio'] as String?) ?? '',
        photoUrl: data?['photoUrl'] as String?,
      );
    });
  }

  // Writes aren't awaited: offline they're queued and streams show them now.
  @override
  Future<void> saveProfile({required String name, required String bio}) async {
    _profile?.set({'name': name, 'bio': bio}, SetOptions(merge: true)).ignore();
    // The Home greeting reads the sign-in name; keep it in step when online.
    unawaited(
      (_auth.currentUser?.updateDisplayName(name) ?? Future<void>.value())
          .catchError((Object _) {}),
    );
  }

  @override
  Future<void> setProfileCurrency(String code) async {
    _account?.update({'profileCurrency': code}).ignore();
  }

  @override
  Stream<bool> locationAllowed() =>
      _account?.snapshots().map(
        (s) => (s.data()?['consents'] as Map?)?['location'] == true,
      ) ??
      const Stream.empty();

  @override
  Future<void> setLocationAllowed({required bool allowed}) async {
    _account?.update({'consents.location': allowed}).ignore();
  }

  @override
  Stream<bool> cameraAllowed() =>
      _account?.snapshots().map(
        (s) => (s.data()?['consents'] as Map?)?['camera'] != false,
      ) ??
      const Stream.empty();

  @override
  Future<void> setCameraAllowed({required bool allowed}) async {
    _account?.update({'consents.camera': allowed}).ignore();
  }

  @override
  Stream<Nominee?> nomineeStream() =>
      _account?.snapshots().map((s) {
        final n = s.data()?['nominee'] as Map?;
        return n == null
            ? null
            : Nominee(name: n['name'] as String, email: n['email'] as String);
      }) ??
      const Stream.empty();

  @override
  Future<void> setNominee(Nominee? nominee) async {
    _account?.update({
      'nominee': nominee == null
          ? null
          : {'name': nominee.name, 'email': nominee.email},
    }).ignore();
  }
}
