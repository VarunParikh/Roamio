import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Name joined your squad", shown to every lead (spec UC-14).
class JoinCard {
  const new({
    required this.id,
    required this.adventureId,
    required this.adventureName,
    required this.memberUid,
    required this.memberName,
  });

  final String id;
  final String adventureId;
  final String adventureName;
  final String memberUid;
  final String memberName;
}

/// A squad action failed; [message] is safe to show as-is.
class SquadException implements Exception {
  new(this.message);

  final String message;

  @override
  String toString() => 'SquadException($message)';
}

abstract interface class SquadService {
  /// The signed-in lead's open join cards, newest first.
  Stream<List<JoinCard>> joinCards();

  /// Squad Leader only (spec UC-15). Clears every lead's card for them.
  Future<void> makeCoLead(String adventureId, String memberUid);

  /// Leads only (spec UC-16). Clears every lead's card for them.
  Future<void> removeMember(String adventureId, String memberUid);

  /// Hides a card for this lead only.
  Future<void> dismiss(String cardId);
}

/// Overridden in `main.dart` with the Firebase implementation.
final squadServiceProvider = Provider<SquadService>(
  (ref) => throw UnimplementedError('squadServiceProvider must be overridden'),
);

final joinCardsProvider = StreamProvider<List<JoinCard>>(
  (ref) => ref.watch(squadServiceProvider).joinCards(),
);
