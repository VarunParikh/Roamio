import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/profile/domain/characters.dart';

/// A person's picture (spec UC-28a): their character on white, or the default
/// for [uid] if they haven't chosen one. A deleted user gets a grey icon, and
/// [loading] a plain circle, so a picture never visibly swaps. It's decorative
/// for TalkBack: the name beside it is what's read.
///
/// [photoUrl] is for Phase 2 uploads only (lib/core/config/phase2.dart); pass
/// it only when they're on.
class CharacterAvatar extends StatelessWidget {
  const new({
    required this.uid,
    this.characterId,
    this.photoUrl,
    this.radius = 20,
    this.deleted = false,
    this.loading = false,
    super.key,
  });

  final String uid;
  final String? characterId;
  final String? photoUrl;
  final double radius;
  final bool deleted;
  final bool loading;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: _picture());

  Widget _picture() {
    if (loading) return _circle();
    if (deleted) {
      return _circle(
        child: Icon(
          Icons.person_outline,
          size: radius * 1.2,
          color: RoamioColors.slate,
        ),
      );
    }
    final photo = photoUrl;
    final chosen = characterById(characterId);
    if (chosen == null && photo != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: RoamioColors.hairline,
        backgroundImage: CachedNetworkImageProvider(photo),
      );
    }
    return ClipOval(
      child: ColoredBox(
        color: Colors.white,
        child: Image.asset(
          (chosen ?? defaultCharacterFor(uid)).asset,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _circle({Widget? child}) => CircleAvatar(
    radius: radius,
    backgroundColor: RoamioColors.hairline,
    child: child,
  );
}
