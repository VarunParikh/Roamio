import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:roamio/core/firebase/firebase_setup.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/sync/sync_controller.dart';

final _plainDecimal = RegExp(r'^\d+(\.\d+)?$');

/// One stored day (`fx_rates/{date}`) as converter rates; rates that aren't
/// plain decimal text are skipped. Null if the document has no rates.
FxRates? ratesFromDoc(String date, Map<String, dynamic> data) {
  final raw = data['rates'];
  if (raw is! Map) return null;
  return FxRates(
    date: date,
    usdRates: {
      for (final MapEntry(:key, :value) in raw.entries)
        if (key is String && value is String && _plainDecimal.hasMatch(value))
          key: value,
    },
  );
}

/// Exchange rates for converting tabs (spec §9.1).
abstract interface class FxRepository {
  /// The rates of [date], or of the latest earlier day when that day has
  /// none (the provider was down), or the earliest there is for a tab older
  /// than all of them; null if there are none at all yet.
  Future<FxRates?> ratesFor(String date);

  /// Asks the server for the latest rates; the latest day there is, or null
  /// if there are none yet. Throws if the server can't be reached.
  Future<String?> refreshLatest();

  /// The newest rates day, live: a day that arrives shows at once (item 14).
  Stream<String?> watchLatestDay();
}

final fxRepositoryProvider = Provider<FxRepository>(
  (ref) => FirebaseFxRepository(FirebaseFirestore.instance, roamioFunctions),
);

/// Rates for one day, kept for the session, and read again on coming back
/// online: a read while offline only finds what's on the phone.
final FutureProviderFamily<FxRates?, String> fxRatesProvider =
    FutureProvider.family<FxRates?, String>((ref, date) {
      ref
        // Read again when a newer day arrives, so rates that come in while
        // the app is open are used at once (item 14).
        ..watch(isOfflineProvider)
        ..watch(latestRatesDayProvider);
      return ref.watch(fxRepositoryProvider).ratesFor(date);
    });

/// The newest rates day, live. One listener on the newest `fx_rates` document.
final StreamProvider<String?> latestRatesDayProvider = StreamProvider<String?>(
  (ref) => ref.watch(fxRepositoryProvider).watchLatestDay(),
);

/// Reads `fx_rates`. Firestore keeps what it has read on the phone, so
/// rates already seen still work offline.
class FirebaseFxRepository implements FxRepository {
  new(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Future<FxRates?> ratesFor(String date) async {
    final latest = await _db
        .collection('fx_rates')
        .where('date', isLessThanOrEqualTo: date)
        .orderBy('date', descending: true)
        .limit(1)
        .get();
    final docs = latest.docs.isNotEmpty
        ? latest.docs
        : (await _db
                  .collection('fx_rates')
                  .where('date', isGreaterThan: date)
                  .orderBy('date')
                  .limit(1)
                  .get())
              .docs;
    if (docs.isEmpty) return null;
    return ratesFromDoc(docs.single.id, docs.single.data());
  }

  @override
  Stream<String?> watchLatestDay() => _db
      .collection('fx_rates')
      .orderBy('date', descending: true)
      .limit(1)
      .snapshots()
      .map((q) => q.docs.isEmpty ? null : q.docs.single.id);

  @override
  Future<String?> refreshLatest() async {
    final result = await _functions
        .httpsCallable('updateFxRates')
        .call<Object?>();
    return (result.data as Map?)?['date'] as String?;
  }
}
