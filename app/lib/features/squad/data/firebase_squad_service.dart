import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roamio/features/squad/data/squad_service.dart';

class FirebaseSquadService implements SquadService {
  new(this._auth, this._db, this._functions);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('users/${_auth.currentUser!.uid}/notifications');

  @override
  Stream<List<JoinCard>> joinCards() => _notifications
      .where('type', isEqualTo: 'member_joined')
      .snapshots()
      .map((q) {
        final docs = [...q.docs]
          ..sort((a, b) => _millis(b).compareTo(_millis(a)));
        return [
          for (final d in docs)
            JoinCard(
              id: d.id,
              adventureId: d['adventureId'] as String,
              adventureName: d['adventureName'] as String,
              memberUid: d['memberUid'] as String,
              memberName: d['memberName'] as String,
            ),
        ];
      });

  // Sorted here rather than with orderBy, which would need a composite index.
  static int _millis(DocumentSnapshot<Map<String, dynamic>> d) =>
      (d.data()?['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;

  @override
  Future<void> makeCoLead(String adventureId, String memberUid) =>
      _call('makeCoLead', adventureId, memberUid);

  @override
  Future<void> removeMember(String adventureId, String memberUid) =>
      _call('removeMember', adventureId, memberUid);

  @override
  Future<void> dismiss(String cardId) => _notifications.doc(cardId).delete();

  @override
  Future<void> demoteCoLead(String adventureId, String memberUid) =>
      _call('demoteCoLead', adventureId, memberUid);

  @override
  Future<void> handOverLeadership(String adventureId, String memberUid) =>
      _call('handOverLeadership', adventureId, memberUid);

  @override
  Future<void> leave(String adventureId) =>
      _call('leaveAdventure', adventureId, null);

  @override
  Future<Map<String, SquadPerson>> peopleOf(List<String> uids) async {
    // Profiles are visible only to squadmates (S3b); one that can't be read
    // is left out rather than hiding everyone's name.
    Future<DocumentSnapshot<Map<String, dynamic>>?> read(String uid) => _db
        .doc('users/$uid')
        .get()
        .then<DocumentSnapshot<Map<String, dynamic>>?>(
          (d) => d,
          onError: (Object _) => null,
        );
    final docs = await Future.wait(uids.map(read));
    return {
      for (final d in docs)
        if (d != null)
          d.id: SquadPerson(
            name: nameFromProfile(d.data()),
            characterId: d.data()?['characterId'] as String?,
            deleted: !d.exists,
          ),
    };
  }

  CollectionReference<Map<String, dynamic>> _pals(String adventureId) =>
      _db.collection('adventures/$adventureId/pals');

  static Pal _pal(QueryDocumentSnapshot<Map<String, dynamic>> d) => Pal(
    id: d.id,
    nickname: d['nickname'] as String,
    characterId: d.data()['characterId'] as String?,
  );

  @override
  Stream<List<Pal>> pals(String adventureId) => _pals(adventureId)
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map(
        (q) => q.docs.map(_pal).toList()
          ..sort(
            (a, b) =>
                a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()),
          ),
      );

  @override
  Stream<List<Pal>> removedPals(String adventureId) =>
      _pals(adventureId)
          .where('status', isEqualTo: 'left')
          .snapshots()
          .map((q) => q.docs.map(_pal).toList());

  // Not awaited: the write is queued offline and the stream shows it at once.
  @override
  Future<void> addPal(
    String adventureId,
    String nickname,
    String characterId,
  ) async {
    _pals(adventureId).add({
      'nickname': nickname,
      'characterId': characterId,
      'addedBy': _auth.currentUser!.uid,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    }).ignore();
  }

  @override
  Future<void> editPal(
    String adventureId,
    String palId,
    String nickname,
    String characterId,
  ) async {
    _pals(adventureId)
        .doc(palId)
        .update({'nickname': nickname, 'characterId': characterId})
        .ignore();
  }

  @override
  Future<void> removePal(String adventureId, String palId) async {
    _pals(adventureId).doc(palId).update({'status': 'left'}).ignore();
  }

  Future<void> _call(String name, String adventureId, String? memberUid) async {
    try {
      await _functions.httpsCallable(name).call<Object?>({
        'adventureId': adventureId,
        'memberUid': ?memberUid,
      });
    } on FirebaseFunctionsException catch (e) {
      const ours = {'failed-precondition', 'permission-denied'};
      throw SquadException(
        ours.contains(e.code) && e.message != null
            ? e.message!
            : e.code == 'unavailable'
            ? 'No connection. Check your internet and try again.'
            : 'Something went wrong. Please try again.',
      );
    }
  }
}
