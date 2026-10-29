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

  /// The adventure list can't be loaded (Home's error state).
  bool failToLoad = false;

  @override
  Stream<List<Adventure>> myAdventures() async* {
    if (failToLoad) throw Exception('adventures unavailable');
    yield adventures;
    yield* _changes.stream;
  }

  final List<String> bannerResets = [];

  @override
  Future<void> resetBanner(String adventureId) async {
    bannerResets.add(adventureId);
    final i = adventures.indexWhere((a) => a.id == adventureId);
    final a = adventures[i];
    adventures[i] = Adventure(
      id: a.id,
      name: a.name,
      description: a.description,
      countryCode: a.countryCode,
      city: a.city,
      startDate: a.startDate,
      endDate: a.endDate,
      baseCurrency: a.baseCurrency,
      leaderUid: a.leaderUid,
      coLeadUids: a.coLeadUids,
      memberUids: a.memberUids,
      activeInviteCode: a.activeInviteCode,
      hasTabs: a.hasTabs,
    );
    _changes.add([...adventures]);
  }

  final List<(String, AdventureEdit)> edits = [];

  @override
  Future<void> update(String adventureId, AdventureEdit edit) async {
    edits.add((adventureId, edit));
    final i = adventures.indexWhere((a) => a.id == adventureId);
    final a = adventures[i];
    adventures[i] = Adventure(
      id: a.id,
      name: edit.name.trim(),
      description: edit.description.trim(),
      countryCode: a.countryCode,
      city: edit.city.trim(),
      startDate: edit.startDate,
      endDate: edit.endDate,
      baseCurrency: edit.baseCurrency ?? a.baseCurrency,
      bannerUrl: a.bannerUrl,
      leaderUid: a.leaderUid,
      coLeadUids: a.coLeadUids,
      memberUids: a.memberUids,
      activeInviteCode: a.activeInviteCode,
      hasTabs: a.hasTabs,
    );
    _changes.add([...adventures]);
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
