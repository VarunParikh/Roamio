import 'package:roamio/features/adventures/ui/adventure_format.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';

/// One day's tabs in the adventure's list.
class DayGroup {
  const new(this.day, this.tabs);

  final DateTime day;
  final List<TabEntry> tabs;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Tabs grouped by day, newest day first; order within a day is kept
/// (spec UC-23).
List<DayGroup> groupByDay(List<TabEntry> tabs) {
  final byDay = <DateTime, List<TabEntry>>{};
  for (final t in tabs) {
    byDay.putIfAbsent(_day(t.date), () => []).add(t);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final d in days) DayGroup(d, byDay[d]!)];
}

/// "Today", "Yesterday", else "Tue, 20 Oct 2026".
String dayLabel(DateTime day, DateTime today) {
  final diff = _day(today).difference(_day(day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return formatDay(day);
}

/// Minor units back into text the amount field accepts: "1234.50".
String amountText(int minor, String currency) {
  final digits = minorUnitDigits(currency);
  final s = minor.abs().toString().padLeft(digits + 1, '0');
  if (digits == 0) return s;
  final cut = s.length - digits;
  return '${s.substring(0, cut)}.${s.substring(cut)}';
}
