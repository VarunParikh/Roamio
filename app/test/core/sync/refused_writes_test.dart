import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/sync/refused_writes.dart';

void main() {
  setUp(refusedWrites.clear);

  test(
    'a queued write the server refuses is kept, so the person is told (item 2)',
    () async {
      final refusal = Completer<void>();
      keepWrite(refusal.future, 'a tab');
      refusal.completeError(Exception('permission denied'));
      await Future<void>.delayed(Duration.zero);
      expect(refusedWrites.refused.value, ['a tab']);
    },
  );

  test('a write that is saved is not reported', () async {
    keepWrite(Future<void>.value(), 'a pal');
    await Future<void>.delayed(Duration.zero);
    expect(refusedWrites.refused.value, isEmpty);
  });
}
