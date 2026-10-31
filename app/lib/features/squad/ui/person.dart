import 'package:flutter/material.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/profile/ui/character_avatar.dart';
import 'package:roamio/features/squad/data/squad_service.dart';

/// The picture for [uid], from what's been looked up about them; a neutral
/// circle until then (spec UC-28a).
class PersonAvatar extends StatelessWidget {
  const new({
    required this.uid,
    required this.person,
    this.radius = 20,
    super.key,
  });

  final String uid;
  final SquadPerson? person;
  final double radius;

  @override
  Widget build(BuildContext context) => CharacterAvatar(
    uid: uid,
    characterId: person?.characterId,
    deleted: person?.deleted ?? false,
    loading: person == null,
    radius: radius,
  );
}

/// A person's picture and name, the one way to show someone (spec UC-28a).
/// [name] replaces their looked-up name, for "You" and the like.
class PersonName extends StatelessWidget {
  const new({
    required this.uid,
    required this.person,
    this.name,
    this.radius = 14,
    this.style,
    super.key,
  });

  final String uid;
  final SquadPerson? person;
  final String? name;
  final double radius;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      PersonAvatar(uid: uid, person: person, radius: radius),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          name ?? person?.name ?? '…',
          style: style,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

/// Who a tab is shared by, as overlapping pictures: up to [max], then "+N",
/// with [firstUid] first (spec UC-23). TalkBack reads their names.
class PeoplePictures extends StatelessWidget {
  const new({
    required this.ids,
    required this.people,
    required this.firstUid,
    this.max = 4,
    this.radius = 12,
    super.key,
  });

  final List<String> ids;
  final Map<String, SquadPerson> people;
  final String firstUid;
  final int max;
  final double radius;

  /// [ids] with [firstUid] first and everyone else in their own order.
  static List<String> ordered(List<String> ids, String firstUid) => [
    if (ids.contains(firstUid)) firstUid,
    for (final id in ids)
      if (id != firstUid) id,
  ];

  /// "Shared by Ari, Cara and 3 others".
  static String sharedByLabel(List<String> names, {int shown = 2}) {
    if (names.isEmpty) return 'Shared by nobody';
    if (names.length == 1) return 'Shared by ${names.single}';
    if (names.length <= shown) {
      return 'Shared by ${names.first} and ${names.last}';
    }
    final rest = names.length - shown;
    return 'Shared by ${names.take(shown).join(', ')} and $rest '
        '${rest == 1 ? 'other' : 'others'}';
  }

  @override
  Widget build(BuildContext context) {
    final inOrder = ordered(ids, firstUid);
    final shown = inOrder.take(max).toList();
    final extra = inOrder.length - shown.length;
    final step = radius * 1.5;
    final diameter = radius * 2;
    final slots = shown.length + (extra > 0 ? 1 : 0);
    return Semantics(
      label: sharedByLabel([
        for (final id in inOrder)
          if (id == firstUid) 'you' else people[id]?.name ?? 'someone',
      ]),
      excludeSemantics: true,
      child: SizedBox(
        width: slots == 0 ? 0 : step * (slots - 1) + diameter,
        height: diameter,
        child: Stack(
          children: [
            for (final (i, id) in shown.indexed)
              Positioned(
                left: step * i,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: PersonAvatar(
                    uid: id,
                    person: people[id],
                    radius: radius,
                  ),
                ),
              ),
            if (extra > 0)
              Positioned(
                left: step * shown.length,
                child: CircleAvatar(
                  radius: radius,
                  backgroundColor: RoamioColors.ink,
                  foregroundColor: Colors.white,
                  child: Text(
                    '+$extra',
                    style: TextStyle(fontSize: radius * 0.8, height: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
