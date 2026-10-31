import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/splits/domain/money.dart';

/// The most that can be settled, [maxTripMinor] in the trip's currency, in
/// [currency]. Null if there's no rate for it.
int? maxInCurrency({
  required int maxTripMinor,
  required String currency,
  required String tripCurrency,
  required FxRates? rates,
}) {
  if (currency == tripCurrency) return maxTripMinor;
  try {
    return rates?.convert(Money(maxTripMinor, tripCurrency), currency).minor;
  } on MissingRateException {
    return null;
  }
}

/// What a payment of [paidMinor] in [currency] records, always in the trip's
/// currency (spec UC-26a). Paying the full amount shown settles it exactly,
/// whatever the rounding; paying more comes out above [maxTripMinor]. Null if
/// there's no rate to work it out.
int? settledInTripCurrency({
  required int paidMinor,
  required String currency,
  required String tripCurrency,
  required int maxTripMinor,
  required FxRates? rates,
}) {
  if (currency == tripCurrency) return paidMinor;
  final full = maxInCurrency(
    maxTripMinor: maxTripMinor,
    currency: currency,
    tripCurrency: tripCurrency,
    rates: rates,
  );
  if (full == null) return null;
  if (paidMinor == full) return maxTripMinor;
  if (paidMinor > full) return maxTripMinor + 1;
  try {
    final minor = rates!
        .convert(Money(paidMinor, currency), tripCurrency)
        .minor;
    return minor < maxTripMinor ? minor : maxTripMinor;
  } on MissingRateException {
    return null;
  }
}
