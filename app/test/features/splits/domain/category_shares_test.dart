import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/splits/domain/category_shares.dart';

void main() {
  group('wholePercents (spec UC-25)', () {
    test('adds up to exactly 100, largest remainders rounded up', () {
      expect(wholePercents([1, 1, 1]), [34, 33, 33]);
      expect(wholePercents([1601227, 916678, 686709, 608212]), [
        42,
        24,
        18,
        16,
      ]);
      expect(wholePercents([1, 1, 1, 1, 1, 1, 1]).reduce((a, b) => a + b), 100);
    });

    test('a tiny share can round to 0, and the total still holds', () {
      expect(wholePercents([100000, 1]), [100, 0]);
    });

    test('one amount is 100; nothing is nothing', () {
      expect(wholePercents([5]), [100]);
      expect(wholePercents(const []), isEmpty);
      expect(wholePercents([0, 0]), [0, 0]);
    });

    test('holds for many awkward splits', () {
      for (var n = 1; n < 40; n++) {
        final amounts = [for (var i = 1; i <= n; i++) i * i * 37 + 11];
        expect(wholePercents(amounts).reduce((a, b) => a + b), 100);
      }
    });
  });

  group('topCategories (spec UC-25)', () {
    test('three or fewer are shown as they are, largest first', () {
      final top = topCategories({'food': 100, 'stay': 300});
      expect(top.map((s) => s.category), ['stay', 'food']);
      expect(top.map((s) => s.percent), [75, 25]);
      expect(top.map((s) => s.minor), [300, 100]);
    });

    test('a single leftover keeps its own name', () {
      final top = topCategories({'a': 40, 'b': 30, 'c': 20, 'd': 10});
      expect(top.map((s) => s.category), ['a', 'b', 'c', 'd']);
    });

    test('more than one leftover becomes Other, with their total', () {
      final top = topCategories({'a': 40, 'b': 30, 'c': 20, 'd': 6, 'e': 4});
      expect(top.map((s) => s.category), ['a', 'b', 'c', null]);
      expect(top.last.minor, 10);
      expect(top.map((s) => s.percent), [40, 30, 20, 10]);
    });

    test('ties always come out in the same order', () {
      final top = topCategories({'b': 10, 'a': 10});
      expect(top.map((s) => s.category), ['a', 'b']);
    });

    test('nothing spent is nothing to show', () {
      expect(topCategories({}), isEmpty);
      expect(topCategories({'a': 0}), isEmpty);
    });
  });

  test('allDays fills the gaps between the first and last day', () {
    final days = allDays({DateTime(2026, 10, 30): 5, DateTime(2026, 11, 2): 7});
    expect(days.map((d) => (d.month, d.day)), [
      (10, 30),
      (10, 31),
      (11, 1),
      (11, 2),
    ]);
    expect(allDays({}), isEmpty);
  });
}
