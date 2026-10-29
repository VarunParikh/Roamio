import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/tab_list.dart';

TabEntry _tab(String id, DateTime date) => TabEntry(
  id: id,
  description: id,
  category: 'food_dining',
  date: date,
  createdBy: 'ari',
  split: TabSplit(
    amount: Money(100, 'THB'),
    payers: const [Payment('ari', 100)],
    participants: const ['ari'],
    fxDate: '2026-10-29',
  ),
);

void main() {
  final today = DateTime(2026, 10, 29);

  group('groupByDay (spec UC-23: grouped by day, newest first)', () {
    test('groups tabs per day, newest day first, order kept within a day', () {
      final groups = groupByDay([
        _tab('a', DateTime(2026, 10, 27)),
        _tab('b', DateTime(2026, 10, 29)),
        _tab('c', DateTime(2026, 10, 27, 18)),
        _tab('d', DateTime(2026, 10, 28)),
      ]);
      expect(groups.map((g) => g.day), [
        DateTime(2026, 10, 29),
        DateTime(2026, 10, 28),
        DateTime(2026, 10, 27),
      ]);
      expect(groups.last.tabs.map((t) => t.id), ['a', 'c']);
    });

    test('an empty list has no groups', () {
      expect(groupByDay(const []), isEmpty);
    });
  });

  group('dayLabel', () {
    test('Today, Yesterday, then the date', () {
      expect(dayLabel(DateTime(2026, 10, 29), today), 'Today');
      expect(dayLabel(DateTime(2026, 10, 28), today), 'Yesterday');
      expect(dayLabel(DateTime(2026, 10, 20), today), 'Tue, 20 Oct 2026');
    });
  });

  group('amountText (stored minor units back to what you type)', () {
    test('uses the currency decimals, no grouping or symbol', () {
      expect(amountText(123450, 'INR'), '1234.50');
      expect(amountText(5, 'USD'), '0.05');
      expect(amountText(1500, 'JPY'), '1500');
      expect(amountText(1250, 'KWD'), '1.250');
      expect(parseAmount(amountText(999999999, 'INR'), 'INR'), 999999999);
    });
  });
}
