import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/data/firebase_adventure_service.dart';

void main() {
  group('whether a list of adventures can be believed yet', () {
    test('nothing on the phone isn’t the same as no adventures', () {
      expect(isKnownAdventureList(isEmpty: true, isFromCache: true), isFalse);
    });

    test('the server saying none is', () {
      expect(isKnownAdventureList(isEmpty: true, isFromCache: false), isTrue);
    });

    test('trips saved on the phone show at once, also offline', () {
      expect(isKnownAdventureList(isEmpty: false, isFromCache: true), isTrue);
    });
  });
}
