import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:roamio/core/sync/refused_writes.dart';

/// A personal budget for one adventure; only its owner can read it
/// (spec UC-19, enforced by the security rules).
class Budget {
  const new({required this.amountMinor, required this.currency});

  final int amountMinor;
  final String currency;
}

/// "You've used 80% of your Goa trip budget" (spec UC-20).
class BudgetAlert {
  const new({
    required this.id,
    required this.adventureId,
    required this.adventureName,
    required this.threshold,
  });

  final String id;
  final String adventureId;
  final String adventureName;
  final int threshold;
}

abstract interface class BudgetService {
  /// The signed-in person's budget for [adventureId], or null.
  Stream<Budget?> budget(String adventureId);

  /// Sets or changes it; a change clears earlier alerts (server-side).
  Future<void> set(String adventureId, Budget budget);

  Future<void> remove(String adventureId);

  /// Budget alerts not yet dismissed, newest first.
  Stream<List<BudgetAlert>> alerts();

  Future<void> dismiss(String alertId);
}

/// Overridden in tests; Firestore otherwise.
final budgetServiceProvider = Provider<BudgetService>(
  (ref) =>
      FirebaseBudgetService(FirebaseAuth.instance, FirebaseFirestore.instance),
);

final StreamProviderFamily<Budget?, String> budgetProvider =
    StreamProvider.family<Budget?, String>(
      (ref, adventureId) =>
          ref.watch(budgetServiceProvider).budget(adventureId),
    );

final budgetAlertsProvider = StreamProvider<List<BudgetAlert>>(
  (ref) => ref.watch(budgetServiceProvider).alerts(),
);

class FirebaseBudgetService implements BudgetService {
  new(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  String get _uid => _auth.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> _doc(String adventureId) =>
      _db.doc('adventures/$adventureId/budgets/$_uid');

  @override
  Stream<Budget?> budget(String adventureId) =>
      _doc(adventureId).snapshots().map((d) {
        final data = d.data();
        if (data == null) return null;
        return Budget(
          amountMinor: data['amountMinor'] as int,
          currency: data['currency'] as String,
        );
      });

  // Writes aren't awaited: they're queued offline and the stream shows them.
  @override
  Future<void> set(String adventureId, Budget budget) async {
    _doc(adventureId)
        .set({
          'amountMinor': budget.amountMinor,
          'currency': budget.currency,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .keepOrReport('your budget');
  }

  @override
  Future<void> remove(String adventureId) async {
    _doc(adventureId).delete().keepOrReport('your budget');
  }

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('users/$_uid/notifications');

  @override
  Stream<List<BudgetAlert>> alerts() => _notifications
      .where('type', isEqualTo: 'budget_alert')
      .snapshots()
      .map(
        (q) => [
          for (final d in q.docs)
            BudgetAlert(
              id: d.id,
              adventureId: d['adventureId'] as String,
              adventureName: d['adventureName'] as String,
              threshold: d['threshold'] as int,
            ),
        ]..sort((a, b) => b.threshold.compareTo(a.threshold)),
      );

  @override
  Future<void> dismiss(String alertId) => _notifications.doc(alertId).delete();
}
