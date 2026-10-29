import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/splits/data/fx_repository.dart';
import 'package:roamio/features/splits/domain/money.dart';

void main() {
  group('ratesFromDoc (fx_rates/{date} → converter)', () {
    test('turns a stored day into rates the converter uses', () {
      final rates = ratesFromDoc('2026-10-27', {
        'date': '2026-10-27',
        'rates': {'INR': '84', 'THB': '33.6'},
        'source': 'open.er-api.com',
      })!;
      expect(rates.date, '2026-10-27');
      // ฿336 → ₹840 at 84 INR and 33.6 THB per USD.
      expect(rates.convert(Money(33600, 'THB'), 'INR'), Money(84000, 'INR'));
    });

    test('skips a malformed rate rather than failing the whole day', () {
      final rates = ratesFromDoc('2026-10-27', {
        'rates': {'INR': '84', 'BAD': '1e5', 'NUM': 33},
      })!;
      expect(rates.hasRate('INR'), isTrue);
      expect(rates.hasRate('BAD'), isFalse);
      expect(rates.hasRate('NUM'), isFalse);
    });

    test('no rates map means no rates', () {
      expect(ratesFromDoc('2026-10-27', {'date': '2026-10-27'}), isNull);
    });
  });
}
