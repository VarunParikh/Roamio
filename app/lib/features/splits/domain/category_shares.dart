/// One slice of Spend by category (spec UC-25); [category] is null for Other.
class CategoryShare {
  const new({
    required this.category,
    required this.minor,
    required this.percent,
  });

  final String? category;
  final int minor;
  final int percent;
}

/// Whole percentages of [amounts] that add up to exactly 100: each is rounded
/// down, then the largest remainders get the leftover points. Earlier amounts
/// win ties. All zeros when there's nothing to share.
List<int> wholePercents(List<int> amounts) {
  final total = amounts.fold(0, (sum, a) => sum + a);
  if (total <= 0) return [for (final _ in amounts) 0];
  final percents = [for (final a in amounts) a * 100 ~/ total];
  final byRemainder = [for (var i = 0; i < amounts.length; i++) i]
    ..sort((x, y) {
      final diff = (amounts[y] * 100 % total) - (amounts[x] * 100 % total);
      return diff != 0 ? diff : x - y;
    });
  final leftover = 100 - percents.fold(0, (sum, p) => sum + p);
  for (var i = 0; i < leftover; i++) {
    percents[byRemainder[i]]++;
  }
  return percents;
}

/// The [top] biggest categories, largest first, then the rest as Other. A
/// single leftover keeps its own name, since "Other" would hide it for
/// nothing.
List<CategoryShare> topCategories(Map<String, int> byCategory, {int top = 3}) {
  final sorted = byCategory.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) {
      final diff = b.value.compareTo(a.value);
      return diff != 0 ? diff : a.key.compareTo(b.key);
    });
  final named = sorted.length <= top + 1 ? sorted : sorted.take(top).toList();
  final other = sorted.skip(named.length).fold(0, (sum, e) => sum + e.value);
  final percents = wholePercents([
    for (final e in named) e.value,
    if (other > 0) other,
  ]);
  return [
    for (final (i, e) in named.indexed)
      CategoryShare(category: e.key, minor: e.value, percent: percents[i]),
    if (other > 0)
      CategoryShare(category: null, minor: other, percent: percents.last),
  ];
}

/// Every day from the first to the last in [byDay], so a day with no spending
/// still shows as a gap.
List<DateTime> allDays(Map<DateTime, int> byDay) {
  if (byDay.isEmpty) return const [];
  final sorted = byDay.keys.toList()..sort();
  final first = sorted.first;
  final last = sorted.last;
  return [
    for (
      var d = first;
      !d.isAfter(last);
      d = DateTime(d.year, d.month, d.day + 1)
    )
      d,
  ];
}
