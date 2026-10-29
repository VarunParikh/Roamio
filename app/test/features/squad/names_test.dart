import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/squad/data/squad_service.dart';

void main() {
  group('display names (spec §8: erasure keeps tabs)', () {
    test('a deleted account, whose profile is gone, is "Deleted user"', () {
      expect(nameFromProfile(null), deletedUserName);
      expect(deletedUserName, 'Deleted user');
    });

    test('a profile shows its name, or "Someone" without one', () {
      expect(nameFromProfile({'name': 'Dan Lee'}), 'Dan Lee');
      expect(nameFromProfile({'bio': 'hi'}), 'Someone');
    });
  });
}
