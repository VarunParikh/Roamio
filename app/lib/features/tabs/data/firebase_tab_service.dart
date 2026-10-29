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

  // Not awaited: the write is queued offline and the stream shows it at once.
  @override
  Future<String> addTab(String adventureId, NewTab tab) async {
    final doc = _tabs(adventureId).doc();
    doc.set({
      'description': tab.description.trim(),
      'category': tab.category,
      'amountMinor': tab.amountMinor,
      'currency': tab.currency,
      'date': isoDate(tab.date),
      'fxDate': tab.fxDate,
      'payers': [
        for (final p in tab.payers)
          {'id': p.payer, 'amountMinor': p.amountMinor},
      ],
      'participants': tab.participants,
      'percentBp': tab.percentBp,
      'memories': <String>[],
      if (tab.location case final p?) 'location': {'lat': p.lat, 'lng': p.lng},
      'createdBy': _auth.currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'deleted': false,
    }).ignore();
    return doc.id;
  }

  static TabEntry _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final currency = data['currency'] as String;
    final percent = (data['percentBp'] as Map?)?.cast<String, int>();
    return TabEntry(
      id: d.id,
      description: (data['description'] as String?) ?? '',
      category: data['category'] as String,
      date: parseIsoDate(data['date'] as String),
      createdBy: data['createdBy'] as String,
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
