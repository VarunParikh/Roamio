import 'package:meta/meta.dart';

/// ISO 4217 currencies whose minor unit is not 2 digits.
const _minorUnitExceptions = <String, int>{
  // 0 decimals
  'BIF': 0, 'CLP': 0, 'DJF': 0, 'GNF': 0, 'ISK': 0, 'JPY': 0, 'KMF': 0,
  'KRW': 0, 'PYG': 0, 'RWF': 0, 'UGX': 0, 'UYI': 0, 'VND': 0, 'VUV': 0,
  'XAF': 0, 'XOF': 0, 'XPF': 0,
  // 3 decimals
  'BHD': 3, 'IQD': 3, 'JOD': 3, 'KWD': 3, 'LYD': 3, 'OMR': 3, 'TND': 3,
};

final _currencyCode = RegExp(r'^[A-Z]{3}$');

/// Number of digits after the decimal point for an ISO 4217 [currency].
int minorUnitDigits(String currency) => _minorUnitExceptions[currency] ?? 2;

/// An amount of money in integer minor units (paise, cents, yen…).
///
/// Money never touches floating point (spec §6).
@immutable
class Money {
  /// Throws [ArgumentError] if [currency] is not a 3-letter upper-case code.
  new(this.minor, this.currency) {
    if (!_currencyCode.hasMatch(currency)) {
      throw ArgumentError.value(currency, 'currency', 'Not an ISO 4217 code');
    }
  }

  factory zero(String currency) => Money(0, currency);

  final int minor;
  final String currency;

  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;

  Money operator +(Money other) => Money(minor + _same(other).minor, currency);
  Money operator -(Money other) => Money(minor - _same(other).minor, currency);
  Money operator -() => Money(-minor, currency);

  Money _same(Money other) {
    if (other.currency != currency) {
      throw ArgumentError(
        'Cannot combine $currency with ${other.currency}; convert first.',
      );
    }
    return other;
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => 'Money($minor $currency)';
}

/// Formats [money] like `₹1,234.56`, or `KWD 1.250` when no [symbol] is known.
String formatMoney(Money money, {String? symbol}) {
  final digits = minorUnitDigits(money.currency);
  final magnitude = money.minor.abs().toString().padLeft(digits + 1, '0');
  final whole = magnitude.substring(0, magnitude.length - digits);
  final fraction = magnitude.substring(magnitude.length - digits);

  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final number = digits == 0 ? grouped : '$grouped.$fraction';
  final prefix = symbol ?? '${money.currency} ';
  return '${money.isNegative ? '-' : ''}$prefix$number';
}
