import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/config/flavor.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/invites/data/invite_service.dart';
import 'package:roamio/features/invites/domain/invite_code.dart';

/// Opens the phone's share sheet; overridden in tests.
final shareTextProvider = Provider<Future<void> Function(String text)>(
  (ref) => throw UnimplementedError('shareTextProvider must be overridden'),
);

/// "Invite your squad" on an adventure (spec UC-9). Leads and co-leads share
/// the link; everyone else is told who can.
class InviteSection extends ConsumerStatefulWidget {
  const new({required this.adventure, required this.myUid, super.key});

  final Adventure adventure;
  final String myUid;

  @override
  ConsumerState<InviteSection> createState() => _InviteSectionState();
}

class _InviteSectionState extends ConsumerState<InviteSection> {
  bool _busy = false;
  String? _code;

  String? get _currentCode => _code ?? widget.adventure.activeInviteCode;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on InviteException catch (e) {
      if (mounted) showAuthMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() => _run(() async {
    final invite = await ref
        .read(inviteServiceProvider)
        .createInvite(widget.adventure.id);
    setState(() => _code = invite.code);
    await ref.read(shareTextProvider)(
      inviteMessage(
        adventureName: widget.adventure.name,
        link: inviteLink(siteUrl, invite.code),
        code: invite.code,
      ),
    );
  });

  Future<void> _newLink() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make a new invite link?'),
        content: const Text(
          'The old link and code stop working. Anyone already in the squad '
          'stays in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('New link'),
          ),
        ],
      ),
    );
    if (!(sure ?? false)) return;
    await _run(() async {
      final service = ref.read(inviteServiceProvider);
      await service.revokeInvite(widget.adventure.id);
      final invite = await service.createInvite(widget.adventure.id);
      setState(() => _code = invite.code);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!widget.adventure.isLead(widget.myUid)) {
      return Text(
        'Want to add someone? Ask the squad leader for the invite link.',
        style: text.bodyMedium?.copyWith(color: RoamioColors.slate),
      );
    }
    final code = _currentCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Invite your squad', style: text.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Share the link in any chat. It works for 14 days.',
          style: text.bodyMedium?.copyWith(color: RoamioColors.slate),
        ),
        if (code != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text(formatCode(code), style: text.headlineSmall),
              subtitle: const Text('Invite code'),
              trailing: IconButton(
                tooltip: 'Copy code',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: formatCode(code)),
                  );
                  if (context.mounted) showAuthMessage(context, 'Code copied');
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Share invite',
          icon: Icons.ios_share_rounded,
          busy: _busy,
          pulse: code == null,
          onPressed: _share,
        ),
        if (code != null)
          TextButton(
            onPressed: _busy ? null : _newLink,
            child: const Text('Make a new link'),
          ),
      ],
    );
  }
}
