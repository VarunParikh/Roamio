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

  @override
  Future<Map<String, String>> namesOf(List<String> uids) async => {
    for (final uid in uids) uid: names[uid] ?? uid,
  };

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
