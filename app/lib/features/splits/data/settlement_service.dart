import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:roamio/core/sync/refused_writes.dart';

/// A recorded "Mark as settled" payment (spec UC-26a), in the trip's
/// currency.
class SettlementEntry {
  const new({
    required this.id,
    required this.from,
    required this.to,
    required this.amountMinor,
    required this.currency,
    required this.date,
    required this.recordedBy,
  });

  final String id;
  final String from;
  final String to;
  final int amountMinor;
  final String currency;
  final String date;
  final String recordedBy;
}

/// The record for a payment. Two phones marking the same payment get the same
/// id, even offline, so it counts once (spec UC-26a). [earlier] is how many
/// payments between the two are already recorded, so another part payment of
/// the same amount is a new record.
String settlementId({
  required String from,
  required String to,
  required int amountMinor,
  required int earlier,
}) => '${from}_${to}_${amountMinor}_$earlier';

abstract interface class SettlementService {
  /// Payments recorded and not undone, newest first.
  Stream<List<SettlementEntry>> settlements(String adventureId);

  /// Records that [from] paid [to] outside the app; works offline. See
  /// [settlementId] for [earlier].
  Future<void> record(
    String adventureId, {
    required String from,
    required String to,
    required int amountMinor,
    required String currency,
    required String date,
    required int earlier,
  });

  /// Undoes a recorded payment; the activity log keeps both.
  Future<void> undo(String adventureId, String settlementId);
}

/// Overridden in tests; Firestore otherwise.
final settlementServiceProvider = Provider<SettlementService>(
  (ref) => FirebaseSettlementService(
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
  ),
);

final StreamProviderFamily<List<SettlementEntry>, String> settlementsProvider =
    StreamProvider.family<List<SettlementEntry>, String>(
      (ref, adventureId) =>
          ref.watch(settlementServiceProvider).settlements(adventureId),
    );

class FirebaseSettlementService implements SettlementService {
  new(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String adventureId) =>
      _db.collection('adventures/$adventureId/settlements');

  @override
  Stream<List<SettlementEntry>> settlements(String adventureId) =>
      _col(adventureId).where('undone', isEqualTo: false).snapshots().map((q) {
        final list = [
          for (final d in q.docs)
            SettlementEntry(
              id: d.id,
              from: d['from'] as String,
              to: d['to'] as String,
              amountMinor: d['amountMinor'] as int,
              currency: d['currency'] as String,
              date: d['date'] as String,
              recordedBy: d['recordedBy'] as String,
            ),
        ]..sort((a, b) => b.date.compareTo(a.date));
        return list;
      });

  // Writes aren't awaited: they're queued offline and the list shows them.
  @override
  Future<void> record(
    String adventureId, {
    required String from,
    required String to,
    required int amountMinor,
    required String currency,
    required String date,
    required int earlier,
  }) async {
    final doc = _col(adventureId).doc(
      settlementId(
        from: from,
        to: to,
        amountMinor: amountMinor,
        earlier: earlier,
      ),
    );
    doc
        .set({
          'from': from,
          'to': to,
          'amountMinor': amountMinor,
          'currency': currency,
          'date': date,
          'recordedBy': _auth.currentUser!.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'undone': false,
        })
        .keepOrReport('a payment you marked as settled', path: doc.path);
  }

  @override
  Future<void> undo(String adventureId, String settlementId) async {
    final doc = _col(adventureId).doc(settlementId);
    doc
        .update({'undone': true, 'undoneBy': _auth.currentUser!.uid})
        .keepOrReport(
          'a payment you undid',
          path: doc.path,
          fields: const {'undone': true},
        );
  }
}
