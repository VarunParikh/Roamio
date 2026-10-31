import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/sync/refused_writes.dart';

class _Store implements QueuedWriteStore {
  List<QueuedWrite> saved = [];

  @override
  Future<List<QueuedWrite>> read() async => saved;

  @override
  Future<void> write(List<QueuedWrite> writes) async => saved = [...writes];
}

QueuedWrite _queued(String path, {String uid = 'ari', String what = 'a tab'}) =>
    QueuedWrite(uid: uid, what: what, path: path);

void main() {
  late RefusedWrites refused;
  late _Store store;

  setUp(() async {
    store = _Store();
    refused = RefusedWrites();
    await refused.load(store, uid: () => 'ari');
  });

  group('in this run of the app (item 2)', () {
    test('a write the server refuses is reported', () async {
      final write = Completer<void>();
      refused.track(write.future, 'a tab');
      write.completeError(Exception('permission denied'));
      await Future<void>.delayed(Duration.zero);
      expect(refused.pending, ['a tab']);
    });

    test('a write that is saved is not reported', () async {
      refused.track(Future<void>.value(), 'a pal');
      await Future<void>.delayed(Duration.zero);
      expect(refused.pending, isEmpty);
    });

    test('tells whoever watches for refusals, for the crash log', () async {
      final seen = <String>[];
      refused
        ..onRefused = seen.add
        ..track(Future<void>.error(Exception('no')), 'a pal');
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['a pal']);
    });
  });

  group('the list kept on the phone, for after a restart (item 2)', () {
    test('holds a queued write until the server answers', () async {
      final write = Completer<void>();
      refused.track(write.future, 'a tab', path: 'adventures/a/tabs/t');
      await Future<void>.delayed(Duration.zero);
      expect(store.saved.single.path, 'adventures/a/tabs/t');

      write.complete();
      await Future<void>.delayed(Duration.zero);
      expect(store.saved, isEmpty);
    });

    test('a newer write to the same record replaces the older one', () async {
      final first = Completer<void>();
      refused
        ..track(first.future, 'a tab', path: 'p', fields: {'a': 1})
        ..track(Completer<void>().future, 'a tab', path: 'p', fields: {'a': 2});
      first.complete();
      await Future<void>.delayed(Duration.zero);
      expect(store.saved.single.fields, {'a': 2});
    });

    test('keeps only values that can be saved and compared', () {
      expect(
        comparableFields({
          'a': 1,
          'b': [
            {'c': 'x'},
          ],
          'at': DateTime(2026),
        }),
        {
          'a': 1,
          'b': [
            {'c': 'x'},
          ],
        },
      );
    });
  });

  group('checking last run’s writes after a restart (item 2)', () {
    Future<RefusedWrites> restartWith(List<QueuedWrite> writes) async {
      store.saved = writes;
      final next = RefusedWrites();
      await next.load(store, uid: () => 'ari');
      return next;
    }

    test('a write that never reached the server is reported', () async {
      final next = await restartWith([_queued('p', what: 'a pal')]);
      await next.checkEarlier((_) async => false);
      expect(next.pending, ['a pal']);
      expect(store.saved, isEmpty);
    });

    test('a write that was saved is quietly forgotten', () async {
      final next = await restartWith([_queued('p')]);
      await next.checkEarlier((_) async => true);
      expect(next.pending, isEmpty);
      expect(store.saved, isEmpty);
    });

    test('kept for later when the answer can’t be read yet', () async {
      final next = await restartWith([_queued('p')]);
      await next.checkEarlier((_) async => null);
      expect(next.pending, isEmpty);
      expect(store.saved, hasLength(1));
    });

    test('someone else’s queued write is left alone', () async {
      final next = await restartWith([_queued('p', uid: 'bea')]);
      var asked = 0;
      await next.checkEarlier((_) async {
        asked++;
        return false;
      });
      expect(asked, 0);
      expect(next.pending, isEmpty);
      expect(store.saved, hasLength(1));
    });

    test('this run’s writes are never checked: they still report', () async {
      refused.track(Completer<void>().future, 'a tab', path: 'p');
      var asked = 0;
      await refused.checkEarlier((_) async {
        asked++;
        return false;
      });
      expect(asked, 0);
    });
  });

  group('writeApplied', () {
    QueuedWrite w({bool mustExist = true, Map<String, Object?>? fields}) =>
        QueuedWrite(
          uid: 'ari',
          what: 'x',
          path: 'p',
          mustExist: mustExist,
          fields: fields ?? const {},
        );

    test('a new record must be there', () {
      expect(writeApplied(w(), {'any': 1}), isTrue);
      expect(writeApplied(w(), null), isFalse);
    });

    test('an edit must have its values, whatever else is there', () {
      final edit = w(
        fields: {
          'amountMinor': 500,
          'payers': [
            {'id': 'ari', 'amountMinor': 500},
          ],
        },
      );
      final saved = {
        'amountMinor': 500,
        'status': 'waiting',
        'payers': [
          {'amountMinor': 500, 'id': 'ari'},
        ],
      };
      expect(writeApplied(edit, saved), isTrue);
      expect(writeApplied(edit, {...saved, 'amountMinor': 400}), isFalse);
    });

    test('a removed record must be gone', () {
      expect(writeApplied(w(mustExist: false), null), isTrue);
      expect(writeApplied(w(mustExist: false), {'a': 1}), isFalse);
    });
  });
}
