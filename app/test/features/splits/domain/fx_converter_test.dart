import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/splits/domain/money.dart';

void main() {
  // Units of each currency per 1 USD, as stored in fx_rates/{date}.
  final rates = FxRates(
    date: '2026-10-27',
    usdRates: const {
      'INR': '84.00',
      'EUR': '0.80',
      'JPY': '150',
      'KWD': '0.3',
      'THB': '35.5',
    },
  );

  group('FxRates.convert', () {
    test('converts from USD using the rate', () {
      expect(rates.convert(Money(10000, 'USD'), 'INR'), Money(840000, 'INR'));
    });

    test('converts to USD', () {
      expect(rates.convert(Money(840000, 'INR'), 'USD'), Money(10000, 'USD'));
    });

    test('cross-converts through USD', () {
      // €8.00 = $10.00 = ₹840.00
      expect(rates.convert(Money(800, 'EUR'), 'INR'), Money(84000, 'INR'));
    });

    test('handles 0-decimal and 3-decimal currencies', () {
      // ¥1,500 = $10.00 = KWD 3.000
      expect(rates.convert(Money(1500, 'JPY'), 'KWD'), Money(3000, 'KWD'));
      // KWD 3.000 = $10.00 = ₹840.00
      expect(rates.convert(Money(3000, 'KWD'), 'INR'), Money(84000, 'INR'));
    });

    test('rounds half to even', () {
      // ₹0.01 → EUR: 0.01 / 84 * 0.80 = €0.0000952 → rounds to €0.00.
      expect(rates.convert(Money(1, 'INR'), 'EUR'), Money(0, 'EUR'));
      // $0.25 → JPY: 37.5 → 38 (half to even: 37.5 → 38).
      expect(rates.convert(Money(25, 'USD'), 'JPY'), Money(38, 'JPY'));
      // $0.15 → JPY: 22.5 → 22 (half to even keeps the even neighbour).
      expect(rates.convert(Money(15, 'USD'), 'JPY'), Money(22, 'JPY'));
    });

    test('rounds negative amounts symmetrically', () {
      expect(rates.convert(Money(-25, 'USD'), 'JPY'), Money(-38, 'JPY'));
      expect(rates.convert(Money(-15, 'USD'), 'JPY'), Money(-22, 'JPY'));
      expect(rates.convert(Money(-10000, 'USD'), 'INR'), Money(-840000, 'INR'));
    });

    test('rounds non-halfway results to the nearest unit', () {
      // ฿100.00 → INR: 100 / 35.5 * 84 = 236.6197… → ₹236.62
      expect(rates.convert(Money(10000, 'THB'), 'INR'), Money(23662, 'INR'));
    });

    test(
      'returns the same money when currencies match, even without a rate',
      () {
        expect(rates.convert(Money(123, 'GBP'), 'GBP'), Money(123, 'GBP'));
      },
    );

    test('throws MissingRateException for an unknown currency', () {
      expect(
        () => rates.convert(Money(100, 'GBP'), 'INR'),
        throwsA(
          isA<MissingRateException>()
              .having((e) => e.currency, 'currency', 'GBP')
              .having((e) => e.toString(), 'message', contains('GBP')),
        ),
      );
      expect(
        () => rates.convert(Money(100, 'INR'), 'GBP'),
        throwsA(isA<MissingRateException>()),
      );
    });

    test('knows whether it has a rate', () {
      expect(rates.hasRate('INR'), isTrue);
      expect(rates.hasRate('USD'), isTrue);
      expect(rates.hasRate('GBP'), isFalse);
    });
  });

  group('FxRates validation', () {
    test('rejects rates that are not positive plain decimals', () {
      for (final bad in ['0', '0.00', '-1', 'abc', '1e5', '', '1.', '.5']) {
        expect(
          () => FxRates(date: '2026-10-27', usdRates: {'INR': bad}),
          throwsFormatException,
          reason: 'rate "$bad" should be rejected',
        );
      }
    });

    test('rejects a malformed date', () {
      expect(
        () => FxRates(date: '27-10-2026', usdRates: const {}),
        throwsFormatException,
      );
    });
  });
}
