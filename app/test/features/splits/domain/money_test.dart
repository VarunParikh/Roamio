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
  group('parseAmount (typed amounts, no floats)', () {
    test('reads whole and decimal amounts into minor units', () {
      expect(parseAmount('1234', 'INR'), 123400);
      expect(parseAmount('1,234.5', 'INR'), 123450);
      expect(parseAmount(' 0.05 ', 'USD'), 5);
      expect(parseAmount('12.', 'EUR'), 1200);
      expect(parseAmount('.5', 'EUR'), 50);
      expect(parseAmount('1500', 'JPY'), 1500);
      expect(parseAmount('1.250', 'KWD'), 1250);
    });

    test('refuses more decimals than the currency has', () {
      expect(parseAmount('1.234', 'INR'), isNull);
      expect(parseAmount('15.5', 'JPY'), isNull);
    });

    test('refuses empty, negative and non-numbers', () {
      for (final bad in ['', ' ', '-5', 'abc', '1.2.3', '1e3', '₹100', ',']) {
        expect(parseAmount(bad, 'INR'), isNull, reason: bad);
      }
    });

    test('keeps every digit of the largest tab', () {
      expect(parseAmount('9,999,999.99', 'INR'), 999999999);
      expect(parseAmount('9999999.999', 'KWD'), 9999999999);
    });
  });

  group('maxTabMinor (spec UC-21: up to 10,000,000 in that currency)', () {
    test('scales with the currency minor unit', () {
      expect(maxTabMinor('INR'), 1000000000);
      expect(maxTabMinor('JPY'), 10000000);
      expect(maxTabMinor('KWD'), 10000000000);
    });
  });
}
