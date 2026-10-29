import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/auth/domain/age.dart';

void main() {
  DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

  group('ageOn', () {
    test('counts whole years, turning older on the birthday', () {
      expect(ageOn(d(2008, 10, 30), d(2026, 10, 29)), 17);
      expect(ageOn(d(2008, 10, 30), d(2026, 10, 30)), 18);
      expect(ageOn(d(2008, 10, 30), d(2026, 12, 31)), 18);
    });

    test('a 29 February birthday turns older on 1 March in common years', () {
      expect(ageOn(d(2008, 2, 29), d(2026, 2, 28)), 17);
      expect(ageOn(d(2008, 2, 29), d(2026, 3, 1)), 18);
      expect(ageOn(d(2008, 2, 29), d(2028, 2, 29)), 20);
    });

    test('ignores the time of day', () {
      expect(
        ageOn(DateTime(2008, 10, 30, 23, 59), DateTime(2026, 10, 30, 0, 1)),
        18,
      );
    });
  });

  group('bracketFor (spec UC-4, §7)', () {
    final today = d(2026, 10, 29);

    test('under 13 is refused', () {
      expect(bracketFor(d(2013, 10, 30), today), AgeBracket.underThirteen);
    });

    test('13 to 17 needs parental consent', () {
      expect(bracketFor(d(2013, 10, 29), today), AgeBracket.minor);
      expect(bracketFor(d(2008, 10, 30), today), AgeBracket.minor);
    });

    test('18 and over is an adult', () {
      expect(bracketFor(d(2008, 10, 29), today), AgeBracket.adult);
      expect(bracketFor(d(1960, 1, 1), today), AgeBracket.adult);
    });
  });

  group('dobProblem', () {
    final today = d(2026, 10, 29);

    test('accepts a plausible date of birth', () {
      expect(dobProblem(d(2000, 1, 1), today), isNull);
    });

    test('rejects a missing, future or impossible date', () {
      expect(dobProblem(null, today), DobProblem.missing);
      expect(dobProblem(d(2026, 10, 30), today), DobProblem.inFuture);
      expect(dobProblem(d(1906, 10, 28), today), DobProblem.tooOld);
    });

    test('the oldest accepted age is 120', () {
      expect(dobProblem(d(1906, 10, 29), today), isNull);
    });
  });

  group('isoDate', () {
    test('formats as yyyy-mm-dd for storage', () {
      expect(isoDate(d(2008, 2, 9)), '2008-02-09');
    });

    test('parses yyyy-mm-dd back', () {
      expect(parseIsoDate('2008-02-09'), d(2008, 2, 9));
      expect(() => parseIsoDate('09-02-2008'), throwsFormatException);
    });
  });
}
