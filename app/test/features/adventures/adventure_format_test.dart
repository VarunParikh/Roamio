import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/ui/adventure_format.dart';

import 'adventure_test.dart' show trip;

void main() {
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  test('formats date ranges compactly', () {
    expect(
      formatDateRange(d(2026, 10, 29), d(2026, 11, 2)),
      '29 Oct – 2 Nov 2026',
    );
    expect(formatDateRange(d(2026, 12, 1), d(2026, 12, 5)), '1 – 5 Dec 2026');
    expect(
      formatDateRange(d(2026, 12, 28), d(2027, 1, 3)),
      '28 Dec 2026 – 3 Jan 2027',
    );
    expect(formatDateRange(d(2026, 12, 1), d(2026, 12, 1)), '1 Dec 2026');
  });

  test('labels where a trip stands', () {
    final today = d(2026, 10, 29);
    expect(
      statusLabel(trip('a', d(2026, 10, 28), d(2026, 11, 1)), today),
      'Happening now',
    );
    expect(
      statusLabel(trip('a', d(2026, 10, 30), d(2026, 11, 1)), today),
      'Starts tomorrow',
    );
    expect(
      statusLabel(trip('a', d(2026, 11, 10), d(2026, 11, 12)), today),
      'In 12 days',
    );
    expect(
      statusLabel(trip('a', d(2026, 9, 1), d(2026, 9, 5)), today),
      'Ended',
    );
  });
}
