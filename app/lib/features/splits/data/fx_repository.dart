import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';

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
  /// none (the provider was down); null if there are none at all yet.
  Future<FxRates?> ratesFor(String date);
}

final fxRepositoryProvider = Provider<FxRepository>(
  (ref) => FirebaseFxRepository(FirebaseFirestore.instance),
);

/// Rates for one day, read once and kept for the session.
final FutureProviderFamily<FxRates?, String> fxRatesProvider =
    FutureProvider.family<FxRates?, String>(
      (ref, date) => ref.watch(fxRepositoryProvider).ratesFor(date),
    );

/// Reads `fx_rates`. Firestore keeps what it has read on the phone, so
/// rates already seen still work offline.
class FirebaseFxRepository implements FxRepository {
  new(this._db);

  final FirebaseFirestore _db;

  @override
  Future<FxRates?> ratesFor(String date) async {
    final latest = await _db
        .collection('fx_rates')
        .where('date', isLessThanOrEqualTo: date)
        .orderBy('date', descending: true)
        .limit(1)
        .get();
    if (latest.docs.isEmpty) return null;
    final doc = latest.docs.single;
    return ratesFromDoc(doc.id, doc.data());
  }
}
