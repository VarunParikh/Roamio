import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';

final _goa = Adventure(
  id: 'goa',
  name: 'Goa',
  description: 'Beach week',
  countryCode: 'IN',
  city: 'Panjim',
  startDate: DateTime(2026, 12),
  endDate: DateTime(2026, 12, 8),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari', 'cara'],
);

AdventureEdit _form({
  String name = 'Goa',
  String description = 'Beach week',
  String city = 'Panjim',
  DateTime? start,
  DateTime? end,
  String currency = 'INR',
}) => editChanges(
  opened: _goa,
  name: name,
  description: description,
  city: city,
  start: start ?? DateTime(2026, 12),
  end: end ?? DateTime(2026, 12, 8),
  currency: currency,
);

void main() {
  test('an unchanged form sends nothing, so it can’t overwrite anyone', () {
    final edit = _form();
    expect(edit.name, isNull);
    expect(edit.description, isNull);
    expect(edit.city, isNull);
    expect(edit.startDate, isNull);
    expect(edit.endDate, isNull);
    expect(edit.baseCurrency, isNull);
  });

  test('only the field that changed is sent (item 6)', () {
    final edit = _form(name: 'Goa trip');
    expect(edit.name, 'Goa trip');
    expect(edit.description, isNull);
    expect(edit.city, isNull);
    expect(edit.startDate, isNull);
  });

  test('a change that is only spaces at the ends is not a change', () {
    expect(_form(name: '  Goa ').name, isNull);
  });

  test('sends a new date only when it moved', () {
    expect(_form(end: DateTime(2026, 12, 9)).endDate, DateTime(2026, 12, 9));
    expect(_form(end: DateTime(2026, 12, 8, 15)).endDate, isNull);
  });
}
