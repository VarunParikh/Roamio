import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/profile/domain/characters.dart';

/// A person's picture: their character on white, or else their initial.
/// [photoUrl] is for Phase 2 uploads only (lib/core/config/phase2.dart); pass
/// it only when they're on.
class CharacterAvatar extends StatelessWidget {
  const new({
    required this.name,
    this.characterId,
    this.photoUrl,
    this.radius = 20,
    super.key,
  });

  final String name;
  final String? characterId;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final character = characterById(characterId);
    if (character != null) {
      return Semantics(
        image: true,
        label: character.label,
        child: ClipOval(
          child: ColoredBox(
            color: Colors.white,
            child: Image.asset(
              character.asset,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
        ),
      );
    }
    final photo = photoUrl;
    final initial = name.trim().characters.firstOrNull ?? '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: RoamioColors.hairline,
      foregroundColor: RoamioColors.ink,
      backgroundImage: photo == null ? null : CachedNetworkImageProvider(photo),
      child: photo == null
          ? Text(initial, style: TextStyle(fontSize: radius * 0.8, height: 1))
          : null,
    );
  }
}
