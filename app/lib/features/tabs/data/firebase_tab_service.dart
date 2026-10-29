import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/features/auth/domain/age.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/new_tab.dart';

class FirebaseTabService implements TabService {
  new(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _tabs(String adventureId) =>
      _db.collection('adventures/$adventureId/tabs');

  @override
  Stream<List<TabEntry>> tabs(String adventureId) =>
      _tabs(adventureId)
          .where('deleted', isEqualTo: false)
          .snapshots()
          .map((q) {
            final entries = q.docs.map(_fromDoc).toList()
              ..sort((a, b) => b.date.compareTo(a.date));
            return entries;
          });

  /// The fields a tab's creator writes (DATA_MODEL.md). On an edit, a
  /// removed location is deleted; on a new tab it's simply left out.
  static Map<String, Object?> _fields(NewTab tab, {required bool isNew}) => {
    'description': tab.description.trim(),
    'category': tab.category,
    'amountMinor': tab.amountMinor,
    'currency': tab.currency,
    'date': isoDate(tab.date),
    'fxDate': tab.fxDate,
    'payers': [
      for (final p in tab.payers) {'id': p.payer, 'amountMinor': p.amountMinor},
    ],
    'participants': tab.participants,
    'percentBp': tab.percentBp,
    if (tab.location case final p?)
      'location': {'lat': p.lat, 'lng': p.lng}
    else if (!isNew)
      'location': FieldValue.delete(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  // Writes aren't awaited: they're queued offline and streams show them now.
  @override
  Future<String> addTab(String adventureId, NewTab tab) async {
    final doc = _tabs(adventureId).doc();
    doc.set({
      ..._fields(tab, isNew: true),
      'memories': <String>[],
      'createdBy': _auth.currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'deleted': false,
    }).ignore();
    return doc.id;
  }

  @override
  Stream<TabEntry?> tab(String adventureId, String tabId) =>
      _tabs(adventureId)
          .doc(tabId)
          .snapshots()
          .map((d) => d.exists ? _fromDoc(d) : null);

  @override
  Future<void> updateTab(String adventureId, String tabId, NewTab tab) async {
    _tabs(adventureId).doc(tabId).update(_fields(tab, isNew: false)).ignore();
  }

  @override
  Future<void> deleteTab(String adventureId, String tabId) async {
    _tabs(adventureId).doc(tabId).update({
      'deleted': true,
      'deletedBy': _auth.currentUser!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }).ignore();
  }

  static TabEntry _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data()!;
    final currency = data['currency'] as String;
    final percent = (data['percentBp'] as Map?)?.cast<String, int>();
    return TabEntry(
      id: d.id,
      description: (data['description'] as String?) ?? '',
      category: data['category'] as String,
      date: parseIsoDate(data['date'] as String),
      createdBy: data['createdBy'] as String,
      deleted: data['deleted'] == true,
      memories: ((data['memories'] as List?) ?? const []).cast<String>(),
      location: switch (data['location']) {
        {'lat': final num lat, 'lng': final num lng} => MapPoint(
          lat.toDouble(),
          lng.toDouble(),
        ),
        _ => null,
      },
      split: TabSplit(
        amount: Money(data['amountMinor'] as int, currency),
        payers: [
          for (final p in (data['payers'] as List).cast<Map<String, dynamic>>())
            Payment(p['id'] as String, p['amountMinor'] as int),
        ],
        participants: (data['participants'] as List).cast<String>(),
        percentBp: percent,
        fxDate: data['fxDate'] as String,
      ),
    );
  }
}
