import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/profile/ui/character_avatar.dart';
import 'package:roamio/features/squad/data/squad_service.dart';

enum _PalAction { rename, remove }

/// A pal in the squad list, with a Pal badge (spec UC-18). Leads get
/// Rename and Remove.
class PalTile extends ConsumerWidget {
  const new({
    required this.adventure,
    required this.pal,
    required this.canManage,
    required this.allPals,
    super.key,
  });

  final Adventure adventure;
  final Pal pal;
  final bool canManage;
  final List<Pal> allPals;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CharacterAvatar(uid: pal.id),
    title: Text(pal.nickname),
    subtitle: const Text('Pal', style: TextStyle(color: RoamioColors.slate)),
    trailing: canManage
        ? PopupMenuButton<_PalAction>(
            tooltip: 'Options',
            onSelected: (action) => _run(context, ref, action),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _PalAction.rename, child: Text('Rename')),
              PopupMenuItem(
                value: _PalAction.remove,
                child: Text('Remove from squad'),
              ),
            ],
          )
        : null,
  );

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    _PalAction action,
  ) async {
    final squad = ref.read(squadServiceProvider);
    switch (action) {
      case _PalAction.rename:
        final name = await askPalNickname(
          context,
          title: 'Rename ${pal.nickname}',
          action: 'Save',
          initial: pal.nickname,
          taken: [
            for (final p in allPals)
              if (p.id != pal.id) p.nickname,
          ],
        );
        if (name != null) await squad.renamePal(adventure.id, pal.id, name);
      case _PalAction.remove:
        final sure = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Remove ${pal.nickname} from ${adventure.name}?'),
            content: const Text(
              'Tabs they’re already on keep their share; they can’t be added '
              'to new ones.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (sure ?? false) await squad.removePal(adventure.id, pal.id);
    }
  }
}

/// Asks for a pal's nickname; null if cancelled. Nicknames are trimmed,
/// 1–30 characters, and unique among [taken] ignoring case.
Future<String?> askPalNickname(
  BuildContext context, {
  required String title,
  required String action,
  required List<String> taken,
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (_) => _NicknameDialog(
    title: title,
    action: action,
    taken: taken,
    initial: initial,
  ),
);

class _NicknameDialog extends StatefulWidget {
  const new({
    required this.title,
    required this.action,
    required this.taken,
    required this.initial,
  });

  final String title;
  final String action;
  final List<String> taken;
  final String initial;

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  late final _field = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _field.text.trim();
    final clash = widget.taken
        .where((t) => t.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    setState(
      () => _error = name.isEmpty
          ? 'Enter a nickname.'
          : clash != null
          ? 'There’s already a pal called $clash.'
          : null,
    );
    if (_error == null) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _field,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      inputFormatters: [LengthLimitingTextInputFormatter(30)],
      decoration: InputDecoration(
        labelText: 'Nickname',
        helperText: 'Just a nickname: no phone, email or photo.',
        errorText: _error,
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.action)),
    ],
  );
}
