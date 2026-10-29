import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/squad/ui/pals.dart';
import 'package:roamio/features/sync/sync_banner.dart';
import 'package:roamio/features/sync/sync_controller.dart';

enum _Action { makeCoLead, makeMember, makeLeader, remove }

/// The squad on an adventure (spec UC-15 to UC-18): everyone with their
/// role, a 🎩 on leads, pals with a Pal badge, the actions the viewer's
/// role allows, and Leave.
class SquadSection extends ConsumerWidget {
  const new({required this.adventure, required this.myUid, super.key});

  final Adventure adventure;
  final String myUid;

  String _role(String uid) => uid == adventure.leaderUid
      ? 'Squad leader'
      : adventure.coLeadUids.contains(uid)
      ? 'Co-lead'
      : 'Member';

  /// What the viewer may do to [uid]: the leader manages everyone else;
  /// co-leads may only remove plain members.
  List<_Action> _actionsOn(String uid) {
    if (uid == myUid || uid == adventure.leaderUid) return const [];
    final isCoLead = adventure.coLeadUids.contains(uid);
    if (myUid == adventure.leaderUid) {
      return [
        if (isCoLead) _Action.makeMember else _Action.makeCoLead,
        _Action.makeLeader,
        _Action.remove,
      ];
    }
    if (adventure.coLeadUids.contains(myUid) && !isCoLead) {
      return const [_Action.remove];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final uids = adventure.memberUids;
    final names = ref.watch(squadNamesProvider(uids.join(','))).value ?? {};
    String nameOf(String uid) => names[uid] ?? '…';
    final pals = ref.watch(palsProvider(adventure.id)).value ?? const <Pal>[];
    final iLead = adventure.isLead(myUid);
    final offline = ref.watch(isOfflineProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Squad (${uids.length + pals.length})', style: text.headlineSmall),
        const SizedBox(height: 8),
        for (final uid in uids)
          _MemberTile(
            name: uid == myUid ? '${nameOf(uid)} (you)' : nameOf(uid),
            role: _role(uid),
            isLead: adventure.isLead(uid),
            actions: offline ? const [] : _actionsOn(uid),
            onAction: (action) => _run(context, ref, action, uid, nameOf(uid)),
          ),
        for (final pal in pals)
          PalTile(
            adventure: adventure,
            pal: pal,
            canManage: iLead,
            allPals: pals,
          ),
        if (iLead) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _addPal(context, ref, pals),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Add pal'),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: offline ? null : () => _leave(context, ref),
          child: const Text('Leave adventure'),
        ),
        if (offline) const NeedsConnectionNote(),
      ],
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    _Action action,
    String uid,
    String name,
  ) async {
    final squad = ref.read(squadServiceProvider);
    final id = adventure.id;
    final (Future<void> Function() call, String done) = switch (action) {
      _Action.makeCoLead => (
        () => squad.makeCoLead(id, uid),
        '$name is now a co-lead.',
      ),
      _Action.makeMember => (
        () => squad.demoteCoLead(id, uid),
        '$name is now a member.',
      ),
      _Action.makeLeader => (
        () => squad.handOverLeadership(id, uid),
        '$name is now squad leader.',
      ),
      _Action.remove => (
        () => squad.removeMember(id, uid),
        '$name was removed from the squad.',
      ),
    };
    final ask = switch (action) {
      _Action.makeLeader => (
        'Make $name squad leader?',
        'You’ll become a co-lead. Only the squad leader can undo this.',
        'Hand over',
      ),
      _Action.remove => (
        'Remove $name from ${adventure.name}?',
        'They’ll leave the squad. You can invite them again later.',
        'Remove',
      ),
      _ => null,
    };
    final ok =
        ask == null ||
        await _confirm(context, title: ask.$1, body: ask.$2, action: ask.$3);
    if (!ok || !context.mounted) return;
    try {
      await call();
      if (context.mounted) showAuthMessage(context, done);
    } on SquadException catch (e) {
      if (context.mounted) showAuthMessage(context, e.message);
    }
  }

  Future<void> _addPal(
    BuildContext context,
    WidgetRef ref,
    List<Pal> pals,
  ) async {
    final name = await askPalNickname(
      context,
      title: 'Add a pal',
      action: 'Add',
      taken: [for (final p in pals) p.nickname],
    );
    if (name != null) {
      await ref.read(squadServiceProvider).addPal(adventure.id, name);
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final isLeader = myUid == adventure.leaderUid;
    if (isLeader && adventure.memberUids.length > 1) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hand over first'),
          content: const Text(
            'Make someone else squad leader before you leave. Tap ⋮ next '
            'to a member and choose Make squad leader.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final ok = await _confirm(
      context,
      title: 'Leave ${adventure.name}?',
      body: isLeader
          ? 'You’re the only one here, so leaving will archive this adventure.'
          : 'You can rejoin later with a new invite. Tabs you’re on keep '
                'your share.',
      action: 'Leave',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(squadServiceProvider).leave(adventure.id);
      if (context.mounted) {
        showAuthMessage(context, 'You left ${adventure.name}.');
        context.go(AuthRoutes.home);
      }
    } on SquadException catch (e) {
      if (context.mounted) showAuthMessage(context, e.message);
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}

class _MemberTile extends StatelessWidget {
  const new({
    required this.name,
    required this.role,
    required this.isLead,
    required this.actions,
    required this.onAction,
  });

  final String name;
  final String role;
  final bool isLead;
  final List<_Action> actions;
  final ValueChanged<_Action> onAction;

  static const Map<_Action, String> _labels = {
    _Action.makeCoLead: 'Make co-lead',
    _Action.makeMember: 'Make member',
    _Action.makeLeader: 'Make squad leader',
    _Action.remove: 'Remove from squad',
  };

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          backgroundColor: RoamioColors.hairline,
          foregroundColor: RoamioColors.ink,
          child: Text(name.isEmpty ? '?' : name.characters.first),
        ),
        if (isLead)
          const Positioned(
            right: -6,
            top: -10,
            child: Text('🎩', style: TextStyle(fontSize: 16)),
          ),
      ],
    ),
    title: Text(name),
    subtitle: Text(role, style: const TextStyle(color: RoamioColors.slate)),
    trailing: actions.isEmpty
        ? null
        : PopupMenuButton<_Action>(
            tooltip: 'Options',
            onSelected: onAction,
            itemBuilder: (_) => [
              for (final a in actions)
                PopupMenuItem(value: a, child: Text(_labels[a]!)),
            ],
          ),
  );
}
