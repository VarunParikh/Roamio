import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/squad/data/squad_service.dart';

const _ari = SquadPerson(name: 'Ari');
const _bob = SquadPerson(name: 'Bob');

void main() {
  group('combinePeople (item 4)', () {
    late Map<String, StreamController<SquadPerson?>> people;
    late List<Map<String, SquadPerson>> seen;

    Future<void> tick() => Future<void>.delayed(Duration.zero);

    setUp(() {
      people = {
        'ari': StreamController<SquadPerson?>(),
        'bob': StreamController<SquadPerson?>(),
      };
      seen = [];
      addTearDown(() async {
        for (final c in people.values) {
          await c.close();
        }
      });
      combinePeople([
        'ari',
        'bob',
      ], (uid) => people[uid]!.stream).listen(seen.add);
    });

    test('waits for everyone, so names don’t appear one by one', () async {
      people['ari']!.add(_ari);
      await tick();
      expect(seen, isEmpty);
      people['bob']!.add(_bob);
      await tick();
      expect(seen.single.keys, ['ari', 'bob']);
    });

    test('a later change comes through', () async {
      people['ari']!.add(_ari);
      people['bob']!.add(_bob);
      await tick();
      people['bob']!.add(const SquadPerson(name: 'Bobby'));
      await tick();
      expect(seen.last['bob']?.name, 'Bobby');
    });

    test(
      'someone who can’t be read is left out, not hiding the rest',
      () async {
        people['ari']!.add(_ari);
        people['bob']!.addError(Exception('permission denied'));
        await tick();
        expect(seen.single.keys, ['ari']);
      },
    );

    test(
      'someone not known offline is left out, not shown as deleted',
      () async {
        people['ari']!.add(_ari);
        people['bob']!.add(null);
        await tick();
        expect(seen.single.keys, ['ari']);
      },
    );
  });

  test('nobody to look up answers at once', () async {
    expect(await combinePeople([], (_) => const Stream.empty()).first, isEmpty);
  });
}
