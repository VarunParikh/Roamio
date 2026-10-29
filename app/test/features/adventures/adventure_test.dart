import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';

Adventure trip(String id, DateTime start, DateTime end) => Adventure(
  id: id,
  name: 'Trip $id',
  countryCode: 'TH',
  startDate: start,
  endDate: end,
  baseCurrency: 'THB',
  leaderUid: 'ari',
  memberUids: const ['ari'],
);

void main() {
  final today = DateTime(2026, 10, 29);
  DateTime d(int month, int day) => DateTime(2026, month, day);

  group('statusOn (spec UC-11)', () {
    test('active from the first to the last day, inclusive', () {
      expect(
        trip('a', d(10, 29), d(11, 2)).statusOn(today),
        AdventureStatus.active,
      );
      expect(
        trip('a', d(10, 20), d(10, 29)).statusOn(today),
        AdventureStatus.active,
      );
    });

    test('upcoming before it starts; past from the day after it ends', () {
      expect(
        trip('a', d(10, 30), d(11, 2)).statusOn(today),
        AdventureStatus.upcoming,
      );
      expect(
        trip('a', d(10, 20), d(10, 28)).statusOn(today),
        AdventureStatus.past,
      );
    });

    test('ignores the time of day', () {
      expect(
        trip(
          'a',
          d(10, 20),
          d(10, 29),
        ).statusOn(DateTime(2026, 10, 29, 23, 59)),
        AdventureStatus.active,
      );
    });
  });

  group('homeSectionsFor (spec UC-5)', () {
    test('the hero is the active trip, else the next upcoming one', () {
      final active = trip('active', d(10, 25), d(11, 1));
      final soon = trip('soon', d(11, 10), d(11, 12));
      final later = trip('later', d(12, 1), d(12, 5));
      final past = trip('past', d(9, 1), d(9, 5));

      final withActive = homeSectionsFor([later, past, soon, active], today);
      expect(withActive.hero?.id, 'active');
      expect(withActive.upcoming.map((a) => a.id), ['soon', 'later']);
      expect(withActive.past.map((a) => a.id), ['past']);

      final noActive = homeSectionsFor([later, past, soon], today);
      expect(noActive.hero?.id, 'soon');
      expect(noActive.upcoming.map((a) => a.id), ['later']);
    });

    test('two active trips: the one that started most recently leads', () {
      final older = trip('older', d(10, 1), d(11, 30));
      final newer = trip('newer', d(10, 27), d(11, 3));
      final s = homeSectionsFor([older, newer], today);
      expect(s.hero?.id, 'newer');
      expect(s.upcoming.map((a) => a.id), ['older']);
    });

    test('past trips are newest first; empty when there are none', () {
      final s = homeSectionsFor([
        trip('june', d(6, 1), d(6, 5)),
        trip('sept', d(9, 1), d(9, 5)),
      ], today);
      expect(s.hero, isNull);
      expect(s.upcoming, isEmpty);
      expect(s.past.map((a) => a.id), ['sept', 'june']);
      expect(homeSectionsFor(const [], today).isEmpty, isTrue);
    });
  });

  group('draftProblems (spec UC-8)', () {
    test('needs a country, a name and an end on or after the start', () {
      expect(
        draftProblems(
          countryCode: null,
          name: ' ',
          start: d(11, 2),
          end: d(11, 1),
        ),
        {
          DraftProblem.noCountry,
          DraftProblem.noName,
          DraftProblem.endBeforeStart,
        },
      );
      expect(
        draftProblems(
          countryCode: 'TH',
          name: 'Bangkok!',
          start: d(11, 1),
          end: d(11, 1),
        ),
        isEmpty,
      );
    });

    test('names are at most 80 characters and dates are required', () {
      expect(
        draftProblems(
          countryCode: 'TH',
          name: 'x' * 81,
          start: null,
          end: null,
        ),
        {DraftProblem.nameTooLong, DraftProblem.noDates},
      );
    });
  });
}
