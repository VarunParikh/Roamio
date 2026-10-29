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

  Future<void> _call(String name, String adventureId, String memberUid) async {
    try {
      await _functions.httpsCallable(name).call<Object?>({
        'adventureId': adventureId,
        'memberUid': memberUid,
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
