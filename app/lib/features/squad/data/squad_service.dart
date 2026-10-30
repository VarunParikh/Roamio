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

/// Someone on the trip without the app: a nickname and a character, never a
/// real name (spec UC-18).
class Pal {
  const new({required this.id, required this.nickname, this.characterId});

  final String id;
  final String nickname;

  /// Null for a pal from before characters; they show the default picture.
  final String? characterId;
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
  Future<Map<String, SquadPerson>> peopleOf(List<String> uids);

  /// The adventure's active pals, A to Z.
  Stream<List<Pal>> pals(String adventureId);

  /// Leads only (spec UC-18). Works offline and syncs later.
  Future<void> addPal(String adventureId, String nickname, String characterId);

  /// Leads only (spec UC-18). Works offline and syncs later.
  Future<void> editPal(
    String adventureId,
    String palId,
    String nickname,
    String characterId,
  );

  /// Pals who were removed: not in the squad any more, but still on old tabs
  /// with their nickname and picture.
  Stream<List<Pal>> removedPals(String adventureId);

  /// Marks the pal Left: pals are never deleted, so tabs keep their history
  /// (spec UC-16).
  Future<void> removePal(String adventureId, String palId);
}

/// Overridden in `main.dart` with the Firebase implementation.
final squadServiceProvider = Provider<SquadService>(
  (ref) => throw UnimplementedError('squadServiceProvider must be overridden'),
);

/// Shown for someone who deleted their account: tabs keep their id so
/// balances stay right, but their profile is gone (spec §8).
const deletedUserName = 'Deleted user';

/// The name to show for a `users/{uid}` profile; null means it's gone.
String nameFromProfile(Map<String, dynamic>? profile) => profile == null
    ? deletedUserName
    : (profile['name'] as String?) ?? 'Someone';

/// Who someone in a squad is, as the squad sees them.
class SquadPerson {
  const new({required this.name, this.characterId, this.deleted = false});

  final String name;
  final String? characterId;

  /// Their account is gone: "Deleted user".
  final bool deleted;
}

/// Names and characters for a squad, keyed by the comma-joined uids so it
/// reloads when the squad changes.
final FutureProviderFamily<Map<String, SquadPerson>, String>
squadPeopleProvider = FutureProvider.family<Map<String, SquadPerson>, String>(
  (ref, uids) => ref.watch(squadServiceProvider).peopleOf(uids.split(',')),
);

/// Just the names, for the many places that show only those.
final FutureProviderFamily<Map<String, String>, String> squadNamesProvider =
    FutureProvider.family<Map<String, String>, String>((ref, uids) async {
      final people = await ref.watch(squadPeopleProvider(uids).future);
      return {for (final e in people.entries) e.key: e.value.name};
    });

final StreamProviderFamily<List<Pal>, String> palsProvider =
    StreamProvider.family<List<Pal>, String>(
      (ref, adventureId) => ref.watch(squadServiceProvider).pals(adventureId),
    );

final StreamProviderFamily<List<Pal>, String> removedPalsProvider =
    StreamProvider.family<List<Pal>, String>(
      (ref, adventureId) =>
          ref.watch(squadServiceProvider).removedPals(adventureId),
    );

final joinCardsProvider = StreamProvider<List<JoinCard>>(
  (ref) => ref.watch(squadServiceProvider).joinCards(),
);
