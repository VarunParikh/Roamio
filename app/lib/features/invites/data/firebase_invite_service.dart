import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roamio/features/auth/domain/age.dart';
import 'package:roamio/features/invites/data/invite_service.dart';

class FirebaseInviteService implements InviteService {
  new(this._auth, this._db, this._functions);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _saved =>
      _db.collection('users/${_auth.currentUser!.uid}/invites');

  @override
  Future<SharedInvite> createInvite(String adventureId) async {
    final data = await _call('createInvite', {'adventureId': adventureId});
    return SharedInvite(
      code: data['code'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(data['expiresAt'] as int),
    );
  }

  @override
  Future<void> revokeInvite(String adventureId) =>
      _call('revokeInvite', {'adventureId': adventureId});

  @override
  Future<InviteDetails> lookup(String code) async {
    final data = await _call('lookupInvite', {'code': code});
    return InviteDetails(
      code: data['code'] as String,
      adventureId: data['adventureId'] as String,
      adventureName: data['adventureName'] as String,
      leaderName: data['leaderName'] as String,
      leaderUid: (data['leaderUid'] as String?) ?? '',
      leaderCharacterId: data['leaderCharacterId'] as String?,
      countryCode: data['countryCode'] as String,
      startDate: parseIsoDate(data['startDate'] as String),
      endDate: parseIsoDate(data['endDate'] as String),
      expiresAt: switch (data['expiresAt']) {
        final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        _ => null,
      },
    );
  }

  @override
  Future<String> join(String code) async {
    final data = await _call('joinAdventure', {'code': code});
    await forgetCode(code);
    return data['adventureId'] as String;
  }

  @override
  Stream<List<String>> savedCodes() => _saved
      .orderBy('addedAt', descending: true)
      .snapshots()
      .map((q) => [for (final d in q.docs) d.id]);

  @override
  Future<void> saveCode(String code) => _saved.doc(code).set({
    'code': code,
    'addedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> forgetCode(String code) => _saved.doc(code).delete();

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call<Object?>(data);
      return Map<String, dynamic>.from((result.data as Map?) ?? const {});
    } on FirebaseFunctionsException catch (e) {
      const ours = {
        'invalid-argument',
        'not-found',
        'failed-precondition',
        'permission-denied',
      };
      throw InviteException(
        ours.contains(e.code) && e.message != null
            ? e.message!
            : e.code == 'unavailable'
            ? 'No connection. Check your internet and try again.'
            : 'Something went wrong. Please try again.',
      );
    }
  }
}
