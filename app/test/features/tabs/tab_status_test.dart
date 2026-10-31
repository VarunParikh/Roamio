import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

void main() {
  group('TabStatus from what is stored', () {
    test('reads every status', () {
      for (final s in TabStatus.values) {
        expect(TabStatus.fromStored(s.name), s);
      }
    });

    test('anything unknown waits, so it never counts by accident', () {
      expect(TabStatus.fromStored('from_the_future'), TabStatus.waiting);
    });

    test('a tab from before statuses counts as approved', () {
      expect(TabStatus.fromStored(null), TabStatus.approved);
    });
  });
}
