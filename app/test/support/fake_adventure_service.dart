import 'dart:async';

import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';

/// In-memory [AdventureService]: [create] adds to [adventures].
class FakeAdventureService implements AdventureService {
  new([List<Adventure> initial = const []]) : adventures = [...initial];

  final List<Adventure> adventures;
  final List<AdventureDraft> created = [];
  final _changes = StreamController<List<Adventure>>.broadcast();
  bool failNext = false;

  @override
  Stream<List<Adventure>> myAdventures() async* {
    yield adventures;
    yield* _changes.stream;
  }

  @override
  Future<String> create(AdventureDraft draft) async {
    if (failNext) {
      failNext = false;
      throw Exception('offline');
    }
    created.add(draft);
    final id = 'new${created.length}';
    adventures.add(
      Adventure(
        id: id,
        name: draft.name,
        countryCode: draft.countryCode,
        city: draft.city,
        description: draft.description,
        startDate: draft.startDate,
        endDate: draft.endDate,
        baseCurrency: draft.baseCurrency,
        leaderUid: 'ari',
        memberUids: const ['ari'],
      ),
    );
    _changes.add([...adventures]);
    return id;
  }
}
