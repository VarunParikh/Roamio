import 'dart:async';

import 'package:roamio/features/splits/data/fx_repository.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';

/// The same USD rates for every day, or none when [rates] is empty.
class FakeFxRepository implements FxRepository {
  new([this.rates = const {}, this.latest = const {}]);

  Map<String, String> rates;

  /// What Update rates brings in; empty means the provider is down.
  final Map<String, String> latest;
  int refreshes = 0;
  bool failRefresh = false;

  @override
  Future<FxRates?> ratesFor(String date) async =>
      rates.isEmpty ? null : FxRates(date: date, usdRates: rates);

  final _days = StreamController<String?>.broadcast();

  /// How many times the newest day was listened to.
  int listeners = 0;

  /// Makes [day] the newest rates day, as the live listener would see it.
  void arrive(String day, Map<String, String> newRates) {
    rates = newRates;
    _days.add(day);
  }

  @override
  Stream<String?> watchLatestDay() async* {
    listeners++;
    yield rates.isEmpty ? null : '2026-10-29';
    yield* _days.stream;
  }

  @override
  Future<String?> refreshLatest() async {
    refreshes++;
    if (failRefresh) throw Exception('unavailable');
    if (latest.isEmpty) return null;
    rates = latest;
    return '2026-10-29';
  }
}
