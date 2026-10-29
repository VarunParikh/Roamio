import 'package:roamio/features/splits/data/fx_repository.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';

/// The same USD rates for every day, or none when [rates] is empty.
class FakeFxRepository implements FxRepository {
  new([this.rates = const {}]);

  final Map<String, String> rates;

  @override
  Future<FxRates?> ratesFor(String date) async =>
      rates.isEmpty ? null : FxRates(date: date, usdRates: rates);
}
