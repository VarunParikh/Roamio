import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/age.dart';

class FirebaseAdventureService implements AdventureService {
  new(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  String get _uid => _auth.currentUser!.uid;

  @override
  Stream<List<Adventure>> myAdventures() => _db
      .collection('adventures')
      .where('memberUids', arrayContains: _uid)
      .snapshots()
      .map((q) => q.docs.map(_fromDoc).toList());

  // Not awaited: the server's answer never comes offline, and the stream
  // shows the new adventure at once. It goes up with the next sync.
  @override
  Future<String> create(AdventureDraft draft) async {
    final doc = _db.collection('adventures').doc();
    unawaited(
      doc.set({
        'name': draft.name.trim(),
        'description': draft.description.trim(),
        'countryCode': draft.countryCode,
        'city': draft.city.trim(),
        'startDate': isoDate(draft.startDate),
        'endDate': isoDate(draft.endDate),
        'baseCurrency': draft.baseCurrency,
        'bannerUrl': null,
        'createdBy': _uid,
        'createdAt': FieldValue.serverTimestamp(),
        'leaderUid': _uid,
        'coLeadUids': <String>[],
        'memberUids': [_uid],
      }),
    );
    return doc.id;
  }

  // Not awaited: the edit is queued offline and the stream shows it at once.
  @override
  Future<void> update(String adventureId, AdventureEdit edit) async {
    _db.doc('adventures/$adventureId').update({
      'name': edit.name.trim(),
      'description': edit.description.trim(),
      'city': edit.city.trim(),
      'startDate': isoDate(edit.startDate),
      'endDate': isoDate(edit.endDate),
      'baseCurrency': ?edit.baseCurrency,
    }).ignore();
  }

  @override
  Future<void> resetBanner(String adventureId) async {
    _db.doc('adventures/$adventureId').update({'bannerUrl': null}).ignore();
  }

  static Adventure _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    List<String> list(String key) =>
        ((data[key] as List?) ?? const []).cast<String>();
    return Adventure(
      id: d.id,
      name: data['name'] as String,
      description: (data['description'] as String?) ?? '',
      countryCode: data['countryCode'] as String,
      city: (data['city'] as String?) ?? '',
      startDate: parseIsoDate(data['startDate'] as String),
      endDate: parseIsoDate(data['endDate'] as String),
      baseCurrency: data['baseCurrency'] as String,
      bannerUrl: data['bannerUrl'] as String?,
      leaderUid: data['leaderUid'] as String,
      coLeadUids: list('coLeadUids'),
      memberUids: list('memberUids'),
      activeInviteCode: data['activeInviteCode'] as String?,
      hasTabs: data['hasTabs'] == true,
    );
  }
}
