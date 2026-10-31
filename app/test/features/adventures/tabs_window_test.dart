import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';

// A trip that ends on 8 December; ari leads, cara co-leads, bob is a member.
final _trip = Adventure(
  id: 'goa',
  name: 'Goa',
  countryCode: 'IN',
  startDate: DateTime(2026, 12),
  endDate: DateTime(2026, 12, 8),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  coLeadUids: const ['cara'],
  memberUids: const ['ari', 'cara', 'bob'],
);

void main() {
  group('who can add tabs after the trip (spec UC-11)', () {
    test('members add tabs up to the last day of the trip', () {
      expect(_trip.tabsOpenFor('bob', DateTime(2026, 12, 8)), isTrue);
      expect(_trip.tabsOpenFor('bob', DateTime(2026, 12, 9)), isFalse);
    });

    test('leads and co-leads add tabs for 7 days after', () {
      expect(_trip.tabsOpenFor('ari', DateTime(2026, 12, 15)), isTrue);
      expect(_trip.tabsOpenFor('cara', DateTime(2026, 12, 15)), isTrue);
      expect(_trip.tabsOpenFor('ari', DateTime(2026, 12, 16)), isFalse);
    });
  });
}
