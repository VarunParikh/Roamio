import 'dart:math';

import 'package:roamio/features/splits/domain/money.dart';

final _plainDecimal = RegExp(r'^\d+(\.\d+)?$');
final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Thrown when a conversion needs a currency that the day's table lacks.
class MissingRateException implements Exception {
  new(this.currency, this.date);

  final String currency;
  final String date;

  @override
  String toString() => 'MissingRateException: no $currency rate for $date';
}

/// An exact decimal rate held as `units / 10^scale`, so no float is involved.
class _Rate {
  new(this.units, this.scale);

  factory parse(String text) {
    if (!_plainDecimal.hasMatch(text)) {
      throw FormatException('Not a plain decimal rate', text);
    }
    final parts = text.split('.');
    final scale = parts.length == 2 ? parts[1].length : 0;
    final units = BigInt.parse(parts.join());
    if (units == BigInt.zero) {
      throw FormatException('Rate must be positive', text);
    }
    return _Rate(units, scale);
  }

  final BigInt units;
  final int scale;
}

/// One day's exchange rates: units of each currency per 1 USD
/// (the shape stored in `fx_rates/{yyyy-mm-dd}`, spec §9.1).
class FxRates {
  /// Throws [FormatException] for a malformed [date] or rate.
  factory({required String date, required Map<String, String> usdRates}) {
    if (!_isoDate.hasMatch(date)) {
      throw FormatException('Expected yyyy-mm-dd', date);
    }
    return FxRates._(date, {
      for (final MapEntry(:key, :value) in usdRates.entries)
        key: _Rate.parse(value),
    });
  }

  new _(this.date, this._rates);

  final String date;
  final Map<String, _Rate> _rates;

  bool hasRate(String currency) =>
      currency == 'USD' || _rates.containsKey(currency);

  /// Converts [money] into [to], rounding half to even to [to]'s minor unit.
  Money convert(Money money, String to) {
    if (money.currency == to) return money;
    final from = _rateFor(money.currency);
    final target = _rateFor(to);

    // minor_to = minor_from × 10^(dTo − dFrom) × rateTo / rateFrom,
    // with each rate = units / 10^scale; kept as one exact fraction.
    final numerator =
        BigInt.from(money.minor) *
        _pow10(minorUnitDigits(to) + from.scale) *
        target.units;
    final denominator =
        _pow10(minorUnitDigits(money.currency) + target.scale) * from.units;
    return Money(_divideHalfEven(numerator, denominator).toInt(), to);
  }

  _Rate _rateFor(String currency) {
    if (currency == 'USD') return _Rate(BigInt.one, 0);
    return _rates[currency] ?? (throw MissingRateException(currency, date));
  }
}

BigInt _pow10(int exponent) => BigInt.from(10).pow(exponent);

/// Divides with banker's rounding; [denominator] must be positive.
BigInt _divideHalfEven(BigInt numerator, BigInt denominator) {
  final negative = numerator.isNegative;
  final n = numerator.abs();
  var quotient = n ~/ denominator;
  final twiceRemainder = (n - quotient * denominator) * BigInt.two;
  if (twiceRemainder > denominator ||
      (twiceRemainder == denominator && quotient.isOdd)) {
    quotient += BigInt.one;
  }
  return negative ? -quotient : quotient;
}

/// A rate to quote: that many units of one currency are worth that value of
/// another. Quotes 1, or 10, 100… when 1 would round to almost nothing
/// ("1,000 VND = ₹3.36").
({int units, Money value}) rateExample(
  FxRates rates, {
  required String from,
  required String to,
}) {
  final one = pow(10, minorUnitDigits(from)).toInt();
  var units = 1;
  var value = rates.convert(Money(one, from), to);
  while (value.minor < 100 && units < 1000000) {
    units *= 10;
    value = rates.convert(Money(one * units, from), to);
  }
  return (units: units, value: value);
}
