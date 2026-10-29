import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

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

/// Someone on the trip without the app: a nickname only (spec UC-18).
class Pal {
  const new({required this.id, required this.nickname});

  final String id;
  final String nickname;
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

  /// Squad Leader only (spec UC-15).
  Future<void> demoteCoLead(String adventureId, String memberUid);

  /// Squad Leader only; they become a co-lead (spec UC-17).
  Future<void> handOverLeadership(String adventureId, String memberUid);

  /// The signed-in person leaves. The leader must hand over first, unless
  /// they're alone, which archives the adventure (spec UC-17).
  Future<void> leave(String adventureId);

  /// Display names for [uids], from their public profiles.
  Future<Map<String, String>> namesOf(List<String> uids);

  /// The adventure's active pals, A to Z.
  Stream<List<Pal>> pals(String adventureId);

  /// Leads only (spec UC-18). Works offline and syncs later.
  Future<void> addPal(String adventureId, String nickname);

  Future<void> renamePal(String adventureId, String palId, String nickname);

  /// Marks the pal Left: pals are never deleted, so tabs keep their history
  /// (spec UC-16).
  Future<void> removePal(String adventureId, String palId);
}

/// Overridden in `main.dart` with the Firebase implementation.
final squadServiceProvider = Provider<SquadService>(
  (ref) => throw UnimplementedError('squadServiceProvider must be overridden'),
);

/// Names for a squad, keyed by the comma-joined uids so it reloads when
/// the squad changes.
final FutureProviderFamily<Map<String, String>, String> squadNamesProvider =
    FutureProvider.family<Map<String, String>, String>(
      (ref, uids) => ref.watch(squadServiceProvider).namesOf(uids.split(',')),
    );

final StreamProviderFamily<List<Pal>, String> palsProvider =
    StreamProvider.family<List<Pal>, String>(
      (ref, adventureId) => ref.watch(squadServiceProvider).pals(adventureId),
    );

final joinCardsProvider = StreamProvider<List<JoinCard>>(
  (ref) => ref.watch(squadServiceProvider).joinCards(),
);
