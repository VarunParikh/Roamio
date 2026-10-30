import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/profile/domain/characters.dart';
import 'package:roamio/features/profile/ui/character_avatar.dart';
import 'package:roamio/features/profile/ui/character_picker.dart';
import 'package:roamio/features/squad/data/squad_service.dart';

enum _PalAction { edit, remove }

/// A pal in the squad list, with a Pal badge (spec UC-18). Leads get
/// Edit and Remove.
class PalTile extends ConsumerWidget {
  const new({
    required this.adventure,
    required this.pal,
    required this.canManage,
    super.key,
  });

  final Adventure adventure;
  final Pal pal;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CharacterAvatar(uid: pal.id, characterId: pal.characterId),
    title: Text(pal.nickname),
    subtitle: const Text('Pal', style: TextStyle(color: RoamioColors.slate)),
    trailing: canManage
        ? PopupMenuButton<_PalAction>(
            tooltip: 'Options',
            onSelected: (action) => _run(context, ref, action),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _PalAction.edit, child: Text('Edit')),
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
      case _PalAction.edit:
        await showPalForm(context, adventure: adventure, pal: pal);
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

/// The one screen for adding a pal, or editing [pal] if given (spec UC-18).
/// True when saved; false when closed without saving.
Future<bool> showPalForm(
  BuildContext context, {
  required Adventure adventure,
  Pal? pal,
}) async =>
    await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PalForm(adventure: adventure, pal: pal),
      ),
    ) ??
    false;

/// A nickname and a character, both required. Nicknames are trimmed, 1–30
/// characters, and unique among the squad's pals ignoring case.
class _PalForm extends ConsumerStatefulWidget {
  const new({required this.adventure, required this.pal});

  final Adventure adventure;
  final Pal? pal;

  @override
  ConsumerState<_PalForm> createState() => _PalFormState();
}

class _PalFormState extends ConsumerState<_PalForm> {
  late final _field = TextEditingController(text: widget.pal?.nickname);

  /// An older pal's missing or unknown id counts as not chosen yet.
  late String? _character = characterById(widget.pal?.characterId)?.id;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  String get _nickname => _field.text.trim();

  /// The other active pals: their nicknames are taken.
  List<Pal> _others(AsyncValue<List<Pal>> pals) => [
    for (final p in pals.value ?? const <Pal>[])
      if (p.id != widget.pal?.id) p,
  ];

  /// Why it can't be saved yet; null when it can.
  String? _reason(List<Pal> others) {
    final clash = others
        .where((p) => p.nickname.toLowerCase() == _nickname.toLowerCase())
        .firstOrNull;
    if (clash != null) return 'There’s already a pal called ${clash.nickname}.';
    return switch ((_nickname.isEmpty, _character == null)) {
      (true, true) => 'Add a nickname and choose a character.',
      (true, false) => 'Add a nickname.',
      (false, true) => 'Choose a character.',
      (false, false) => null,
    };
  }

  /// The pictures people in this squad show right now.
  Set<String> get _used {
    final members = widget.adventure.memberUids;
    final people = ref.read(squadPeopleProvider(members.join(','))).value ?? {};
    return {
      for (final uid in members)
        if (people[uid] case final person? when !person.deleted)
          _shownFor(uid, person.characterId),
      for (final p in _others(ref.read(palsProvider(widget.adventure.id))))
        _shownFor(p.id, p.characterId),
    };
  }

  static String _shownFor(String id, String? characterId) =>
      (characterById(characterId) ?? defaultCharacterFor(id)).id;

  Future<void> _pick() async {
    FocusScope.of(context).unfocus();
    final id = await showCharacterPicker(
      context,
      current: _character,
      title: _nickname.isEmpty
          ? 'Choose a character'
          : 'Choose a character for $_nickname',
      used: _used,
    );
    if (id != null && mounted) setState(() => _character = id);
  }

  void _save(String character) {
    final squad = ref.read(squadServiceProvider);
    final id = widget.adventure.id;
    final pal = widget.pal;
    // Not awaited: offline the write stays queued, and the list shows it at
    // once.
    unawaited(
      pal == null
          ? squad.addPal(id, _nickname, character)
          : squad.editPal(id, pal.id, _nickname, character),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;
    final reason = _reason(
      _others(ref.watch(palsProvider(widget.adventure.id))),
    );
    final character = _character;
    final slate = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: RoamioColors.slate);
    return AuthScaffold(
      showBack: true,
      title: pal == null ? 'Add a pal' : 'Edit ${pal.nickname}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _field,
            autofocus: pal == null,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(30)],
            decoration: const InputDecoration(
              labelText: 'Nickname',
              helperText:
                  'Just a nickname: no real name, phone, email or photo.',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              CharacterAvatar(
                uid: pal?.id ?? '',
                characterId: character,
                // Nothing to show until there's a choice.
                loading: character == null && pal == null,
                radius: 36,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pick,
                  child: Text(
                    character == null
                        ? 'Choose a character'
                        : 'Change character',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      primary: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reason != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(reason, style: slate, textAlign: TextAlign.center),
              ),
            ),
          PrimaryButton(
            label: pal == null ? 'Add' : 'Save',
            onPressed: reason == null ? () => _save(character!) : null,
          ),
        ],
      ),
    );
  }
}
