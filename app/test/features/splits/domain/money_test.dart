import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/splits/domain/money.dart';

void main() {
  group('minorUnitDigits', () {
    test('uses ISO 4217 minor units', () {
      expect(minorUnitDigits('INR'), 2);
      expect(minorUnitDigits('USD'), 2);
      expect(minorUnitDigits('JPY'), 0);
      expect(minorUnitDigits('KRW'), 0);
      expect(minorUnitDigits('VND'), 0);
      expect(minorUnitDigits('KWD'), 3);
      expect(minorUnitDigits('BHD'), 3);
      expect(minorUnitDigits('OMR'), 3);
    });

    test('defaults to 2 for currencies without an exception', () {
      expect(minorUnitDigits('THB'), 2);
    });
  });

  group('Money', () {
    test('keeps the amount in integer minor units', () {
      final m = Money(123450, 'INR');

      expect(m.minor, 123450);
      expect(m.currency, 'INR');
    });

    test('rejects currency codes that are not three upper-case letters', () {
      expect(() => Money(1, 'inr'), throwsArgumentError);
      expect(() => Money(1, 'IN'), throwsArgumentError);
      expect(() => Money(1, 'INR1'), throwsArgumentError);
    });

    test('adds and subtracts in the same currency', () {
      final a = Money(1000, 'EUR');
      final b = Money(250, 'EUR');

      expect(a + b, Money(1250, 'EUR'));
      expect(b - a, Money(-750, 'EUR'));
    });

    test('refuses to mix currencies', () {
      expect(() => Money(1, 'EUR') + Money(1, 'USD'), throwsArgumentError);
      expect(() => Money(1, 'EUR') - Money(1, 'USD'), throwsArgumentError);
    });

    test('negates, and reports zero and negative amounts', () {
      expect(-Money(500, 'INR'), Money(-500, 'INR'));
      expect(Money(0, 'INR').isZero, isTrue);
      expect(Money(-1, 'INR').isNegative, isTrue);
      expect(Money(1, 'INR').isNegative, isFalse);
    });

    test('zero() builds a zero amount', () {
      expect(Money.zero('JPY'), Money(0, 'JPY'));
    });

    test('is a value: equal amounts and currencies are equal', () {
      expect(Money(5, 'INR'), Money(5, 'INR'));
      expect(Money(5, 'INR').hashCode, Money(5, 'INR').hashCode);
      expect(Money(5, 'INR'), isNot(Money(5, 'USD')));
      expect(Money(5, 'INR'), isNot(Money(6, 'INR')));
    });

    test('toString shows minor units and code for debugging', () {
      expect(Money(123, 'INR').toString(), 'Money(123 INR)');
    });
  });

  group('formatMoney', () {
    test('formats 2-decimal currencies with the symbol', () {
      expect(formatMoney(Money(123456, 'INR'), symbol: '₹'), '₹1,234.56');
      expect(formatMoney(Money(5, 'USD'), symbol: r'$'), r'$0.05');
    });

    test('formats 0-decimal currencies without a decimal point', () {
      expect(formatMoney(Money(1234, 'JPY'), symbol: '¥'), '¥1,234');
    });

    test('formats 3-decimal currencies with three places', () {
      expect(formatMoney(Money(1250, 'KWD'), symbol: 'KD'), 'KD1.250');
    });

    test('falls back to the currency code when no symbol is known', () {
      expect(formatMoney(Money(1250, 'KWD')), 'KWD 1.250');
    });

    test('groups thousands and shows a leading minus for negatives', () {
      expect(
        formatMoney(Money(-123456789, 'EUR'), symbol: '€'),
        '-€1,234,567.89',
      );
      expect(formatMoney(Money(0, 'EUR'), symbol: '€'), '€0.00');
    });
  });
}
