/// Age rules for sign-up (spec UC-4, §7). The server re-checks these when it
/// sets `ageStatus`, so the app's answer is only ever a first guess.
enum AgeBracket { underThirteen, minor, adult }

enum DobProblem { missing, inFuture, tooOld }

const minimumAge = 13;
const adultAge = 18;
const _maximumAge = 120;

/// Whole years from [dob] to [today]. Someone born on 29 February turns a
/// year older on 1 March in common years.
int ageOn(DateTime dob, DateTime today) {
  final hadBirthday =
      today.month > dob.month ||
      (today.month == dob.month && today.day >= dob.day);
  return today.year - dob.year - (hadBirthday ? 0 : 1);
}

AgeBracket bracketFor(DateTime dob, DateTime today) =>
    switch (ageOn(dob, today)) {
      < minimumAge => AgeBracket.underThirteen,
      < adultAge => AgeBracket.minor,
      _ => AgeBracket.adult,
    };

DobProblem? dobProblem(DateTime? dob, DateTime today) {
  if (dob == null) return DobProblem.missing;
  final day = DateTime.utc(dob.year, dob.month, dob.day);
  if (day.isAfter(DateTime.utc(today.year, today.month, today.day))) {
    return DobProblem.inFuture;
  }
  final oldest = DateTime.utc(today.year - _maximumAge, today.month, today.day);
  return day.isBefore(oldest) ? DobProblem.tooOld : null;
}

/// `yyyy-mm-dd`, the stored form of a date of birth (DATA_MODEL.md).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

final _isoDatePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

DateTime parseIsoDate(String text) {
  final m = _isoDatePattern.firstMatch(text);
  if (m == null) throw FormatException('Expected yyyy-mm-dd', text);
  return DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}
