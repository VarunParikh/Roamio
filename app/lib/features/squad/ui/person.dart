import 'package:flutter/material.dart';
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
