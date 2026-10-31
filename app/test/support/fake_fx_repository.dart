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

  @override
  Future<String?> refreshLatest() async {
    refreshes++;
    if (failRefresh) throw Exception('unavailable');
    if (latest.isEmpty) return null;
    rates = latest;
    return '2026-10-29';
  }
}
