import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/splits/domain/settle_amount.dart';

final _rates = FxRates(
  date: '2026-11-01',
  usdRates: const {'INR': '84', 'THB': '35'},
);

int? _settled(int paid, String currency, {FxRates? rates, int max = 50000}) =>
    settledInTripCurrency(
      paidMinor: paid,
      currency: currency,
      tripCurrency: 'THB',
      maxTripMinor: max,
      rates: rates ?? _rates,
    );

void main() {
  group('a payment typed in another currency', () {
    test('in the trip currency, it’s what was typed', () {
      expect(_settled(20000, 'THB'), 20000);
    });

    test('in rupees, it’s recorded in the trip currency', () {
      // ₹840 at 84 to the dollar is $10, which is ฿350.
      expect(_settled(84000, 'INR'), 35000);
    });

    test('the full amount in rupees settles exactly the full amount', () {
      final full = maxInCurrency(
        maxTripMinor: 50000,
        currency: 'INR',
        tripCurrency: 'THB',
        rates: _rates,
      )!;
      expect(_settled(full, 'INR'), 50000);
    });

    test('more than is owed comes out above the limit', () {
      final full = maxInCurrency(
        maxTripMinor: 50000,
        currency: 'INR',
        tripCurrency: 'THB',
        rates: _rates,
      )!;
      expect(_settled(full + 1, 'INR')! > 50000, isTrue);
    });

    test('a lower amount never rounds up past the limit', () {
      expect(_settled(119999, 'INR')! <= 50000, isTrue);
    });

    test('no rates: it can’t be worked out, unless it’s the trip currency', () {
      int? noRates(String c) => settledInTripCurrency(
        paidMinor: 100,
        currency: c,
        tripCurrency: 'THB',
        maxTripMinor: 50000,
        rates: null,
      );
      expect(noRates('INR'), isNull);
      expect(noRates('THB'), 100);
    });

    test('a currency with no rate can’t be worked out', () {
      expect(_settled(100, 'XXX'), isNull);
    });
  });
}
