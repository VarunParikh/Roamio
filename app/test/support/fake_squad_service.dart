import 'dart:async';

import 'package:roamio/features/squad/data/squad_service.dart';

/// In-memory [SquadService]: [cards] are the signed-in lead's join cards;
/// acting on one removes it, as the server does.
class FakeSquadService implements SquadService {
  new([List<JoinCard> initial = const []]) : cards = [...initial];

  final List<JoinCard> cards;
  final List<String> calls = [];
  final _changes = StreamController<List<JoinCard>>.broadcast();

  /// When set, the next action fails with this message.
  String? failNext;

  @override
  Stream<List<JoinCard>> joinCards() async* {
    yield [...cards];
    yield* _changes.stream;
  }

  @override
  Future<void> makeCoLead(String adventureId, String memberUid) =>
      _act('coLead:$adventureId/$memberUid', adventureId, memberUid);

  @override
  Future<void> removeMember(String adventureId, String memberUid) =>
      _act('remove:$adventureId/$memberUid', adventureId, memberUid);

  @override
  Future<void> dismiss(String cardId) async {
    calls.add('dismiss:$cardId');
    cards.removeWhere((c) => c.id == cardId);
    _changes.add([...cards]);
  }

  @override
  Future<void> demoteCoLead(String adventureId, String memberUid) =>
      _act('demote:$adventureId/$memberUid', adventureId, memberUid);

  @override
  Future<void> handOverLeadership(String adventureId, String memberUid) =>
      _act('handOver:$adventureId/$memberUid', adventureId, memberUid);

  @override
  Future<void> leave(String adventureId) =>
      _act('leave:$adventureId', adventureId, '');

  /// Display names; anyone missing is shown by uid.
  final Map<String, String> names = {};

  /// People who deleted their account: their profile is gone.
  final Set<String> deleted = {};

  /// Every list of uids looked up, in order.
  final List<List<String>> lookups = [];

  /// Characters people chose, by uid.
  final Map<String, String> characters = {};

  @override
  Future<Map<String, SquadPerson>> peopleOf(List<String> uids) async {
    lookups.add(uids);
    return {
      for (final uid in uids)
        uid: SquadPerson(
          name: deleted.contains(uid) ? deletedUserName : names[uid] ?? uid,
          characterId: characters[uid],
        ),
    };
  }

  /// Active pals per adventure.
  final Map<String, List<Pal>> palsByAdventure = {};
  final _palChanges = StreamController<void>.broadcast();
  int _nextPal = 0;

  List<Pal> _palsOf(String adventureId) =>
      palsByAdventure.putIfAbsent(adventureId, () => []);

  @override
  Stream<List<Pal>> pals(String adventureId) async* {
    yield [..._palsOf(adventureId)];
    yield* _palChanges.stream.map((_) => [..._palsOf(adventureId)]);
  }

  @override
  Future<void> addPal(String adventureId, String nickname) async {
    calls.add('addPal:$adventureId/$nickname');
    _palsOf(adventureId).add(Pal(id: 'pal${++_nextPal}', nickname: nickname));
    _palChanges.add(null);
  }

  @override
  Future<void> renamePal(
    String adventureId,
    String palId,
    String nickname,
  ) async {
    calls.add('renamePal:$palId/$nickname');
    final pals = _palsOf(adventureId);
    final i = pals.indexWhere((p) => p.id == palId);
    pals[i] = Pal(id: palId, nickname: nickname);
    _palChanges.add(null);
  }

  @override
  Future<void> removePal(String adventureId, String palId) async {
    calls.add('removePal:$palId');
    _palsOf(adventureId).removeWhere((p) => p.id == palId);
    _palChanges.add(null);
  }

  Future<void> _act(String call, String adventureId, String memberUid) async {
    calls.add(call);
    final message = failNext;
    if (message != null) {
      failNext = null;
      throw SquadException(message);
    }
    cards.removeWhere(
      (c) => c.adventureId == adventureId && c.memberUid == memberUid,
    );
    _changes.add([...cards]);
  }
}
