import 'package:flutter/material.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/profile/domain/characters.dart';
import 'package:roamio/features/profile/ui/character_avatar.dart';

/// Lets someone choose their display picture (spec UC-28). Returns the
/// chosen id, or null when they close it without choosing.
Future<String?> showCharacterPicker(BuildContext context, {String? current}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (context, scroll) => _Picker(scroll: scroll, current: current),
      ),
    );

class _Picker extends StatelessWidget {
  const new({required this.scroll, required this.current});

  final ScrollController scroll;
  final String? current;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return CustomScrollView(
      controller: scroll,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Text('Choose your character', style: text.headlineSmall),
          ),
        ),
        for (final group in CharacterGroup.values) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(group.title, style: text.titleMedium),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.extent(
              maxCrossAxisExtent: 80,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final c in characters.where((c) => c.group == group))
                  _Tile(character: c, selected: c.id == current),
              ],
            ),
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const new({required this.character, required this.selected});

  final Character character;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: true,
    selected: selected,
    label: character.label,
    onTap: () => Navigator.pop(context, character.id),
    excludeSemantics: true,
    child: InkResponse(
      onTap: () => Navigator.pop(context, character.id),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? RoamioColors.chartreuse : RoamioColors.hairline,
            width: selected ? 4 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: LayoutBuilder(
            builder: (context, box) => CharacterAvatar(
              name: character.label,
              characterId: character.id,
              radius: box.maxWidth / 2,
            ),
          ),
        ),
      ),
    ),
  );
}
