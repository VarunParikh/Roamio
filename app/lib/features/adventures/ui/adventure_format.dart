import 'package:roamio/features/adventures/domain/adventure.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "29 Oct – 2 Nov 2026", "1 – 5 Dec 2026", "28 Dec 2026 – 3 Jan 2027".
String formatDateRange(DateTime start, DateTime end) {
  final m1 = _months[start.month - 1];
  final m2 = _months[end.month - 1];
  if (start.year != end.year) {
    return '${start.day} $m1 ${start.year} – ${end.day} $m2 ${end.year}';
  }
  if (start.month != end.month) {
    return '${start.day} $m1 – ${end.day} $m2 ${end.year}';
  }
  if (start.day == end.day) return '${start.day} $m1 ${start.year}';
  return '${start.day} – ${end.day} $m1 ${end.year}';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Thu, 29 Oct 2026".
String formatDay(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

/// "Happening now", "Starts tomorrow", "In 12 days", "Ended".
String statusLabel(Adventure a, DateTime today) {
  switch (a.statusOn(today)) {
    case AdventureStatus.active:
      return 'Happening now';
    case AdventureStatus.past:
      return 'Ended';
    case AdventureStatus.upcoming:
      final days = DateTime(
        a.startDate.year,
        a.startDate.month,
        a.startDate.day,
      ).difference(DateTime(today.year, today.month, today.day)).inDays;
      return days == 1 ? 'Starts tomorrow' : 'In $days days';
  }
}
