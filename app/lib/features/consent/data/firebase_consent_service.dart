import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roamio/features/consent/data/consent_service.dart';

class FirebaseConsentService implements ConsentService {
  new(this._auth, this._db, this._functions);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  String get _uid => _auth.currentUser!.uid;

  @override
  Stream<MyConsentRequest?> myRequest() => _db
      .doc('parentalConsents/$_uid')
      .snapshots()
      .map(
        (s) => s.exists
            ? MyConsentRequest(
                parentEmail: s.get('parentEmail') as String,
                status: s.get('status') as String,
              )
            : null,
      );

  @override
  Future<void> requestConsent({
    required String parentEmail,
    required String relationship,
  }) => _call('requestParentalConsent', {
    'parentEmail': parentEmail,
    'relationship': relationship,
  });

  @override
  Future<ConsentDetails> describe({
    required String childUid,
    required String token,
  }) async {
    final data = await _call('describeConsentRequest', {
      'childUid': childUid,
      'token': token,
    });
    return ConsentDetails(
      childFirstName: data['childFirstName'] as String,
      relationship: data['relationship'] as String,
      parentEmail: data['parentEmail'] as String,
    );
  }

  @override
  Future<void> decide({
    required String childUid,
    required String token,
    required bool grant,
  }) => _call('decideParentalConsent', {
    'childUid': childUid,
    'token': token,
    'decision': grant ? 'grant' : 'decline',
  });

  @override
  Stream<List<LinkedChild>> linkedChildren() => _db
      .collection('parentalConsents')
      .where('parentUid', isEqualTo: _uid)
      .where('status', isEqualTo: 'granted')
      .snapshots()
      .asyncMap(
        (q) => Future.wait(
          q.docs.map((d) async {
            final profile = await _db.doc('users/${d.id}').get();
            return LinkedChild(
              uid: d.id,
              name: (profile.data()?['name'] as String?) ?? 'Your child',
              since: (d.data()['decidedAt'] as Timestamp?)?.toDate(),
            );
          }),
        ),
      );

  @override
  Future<void> withdraw(String childUid) =>
      _call('withdrawParentalConsent', {'childUid': childUid});

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call<Object?>(data);
      return Map<String, dynamic>.from((result.data as Map?) ?? const {});
    } on FirebaseFunctionsException catch (e) {
      // Our functions word their errors for people; other failures don't.
      final ours = {
        'invalid-argument',
        'failed-precondition',
        'permission-denied',
        'resource-exhausted',
      };
      throw ConsentException(
        ours.contains(e.code) && e.message != null
            ? e.message!
            : e.code == 'unavailable'
            ? 'No connection. Check your internet and try again.'
            : 'Something went wrong. Please try again.',
      );
    }
  }
}
