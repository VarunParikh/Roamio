import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/ui/adventure_format.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/invites/data/invite_service.dart';
import 'package:roamio/features/invites/domain/invite_code.dart';
import 'package:roamio/features/sync/sync_controller.dart';

/// Looks up [input] and, if it's a live invite, saves it to the person's
/// Invites. Returns a message to show.
Future<String> addInviteCode(WidgetRef ref, String input) async {
  final code = normaliseCode(input);
  if (code == null) return 'That doesn’t look like a Roamio invite code.';
  final service = ref.read(inviteServiceProvider);
  try {
    final details = await service.lookup(code);
    await service.saveCode(code);
    return 'Invite to “${details.adventureName}” added to your Invites.';
  } on InviteException catch (e) {
    return e.message;
  }
}

/// The Invites list on Home (spec UC-13).
class InvitesList extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codes = ref.watch(savedInviteCodesProvider).value ?? const [];
    if (codes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Invites', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        for (final code in codes) _InviteCard(code: code),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _InviteCard extends ConsumerStatefulWidget {
  const new({required this.code});

  final String code;

  @override
  ConsumerState<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<_InviteCard> {
  bool _joining = false;

  String get code => widget.code;

  Future<void> _join(InviteDetails d) async {
    setState(() => _joining = true);
    try {
      await ref.read(inviteServiceProvider).join(code);
      if (mounted) {
        showAuthMessage(
          context,
          'You’re in! ${d.adventureName} is now on your Home.',
        );
      }
    } on InviteException catch (e) {
      if (mounted) {
        showAuthMessage(context, e.message);
        setState(() => _joining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final details = ref.watch(inviteDetailsProvider(code));
    final forget = TextButton(
      onPressed: _joining
          ? null
          : () => ref.read(inviteServiceProvider).forgetCode(code),
      child: const Text('Remove'),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: details.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Row(
            children: [
              Expanded(
                child: Text(
                  e is InviteException
                      ? e.message
                      : 'Couldn’t load this invite.',
                  style: text.bodyMedium,
                ),
              ),
              forget,
            ],
          ),
          data: (d) {
            final flag = ref
                .watch(countriesProvider)
                .value
                ?.byCode(d.countryCode)
                ?.flag;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${flag ?? '🌍'}  ${d.adventureName}',
                  style: text.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'From ${d.leaderName} · '
                  '${formatDateRange(d.startDate, d.endDate)}',
                  style: text.bodyMedium?.copyWith(color: RoamioColors.slate),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _joining || ref.watch(isOfflineProvider)
                            ? null
                            : () => _join(d),
                        child: _joining
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Join squad'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    forget,
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Have an invite code?" (spec UC-12): type or paste a code.
Future<void> showEnterInviteCode(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      // Above the floating bottom bar, not inside the Home tab under it.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _EnterCodeSheet(),
    );

class _EnterCodeSheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_EnterCodeSheet> createState() => _EnterCodeSheetState();
}

class _EnterCodeSheetState extends ConsumerState<_EnterCodeSheet> {
  final _field = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final message = await addInviteCode(ref, _field.text);
    if (!mounted) return;
    if (message.startsWith('Invite to')) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } else {
      setState(() {
        _busy = false;
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      0,
      16,
      16 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Have an invite code?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _field,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [LengthLimitingTextInputFormatter(200)],
          decoration: InputDecoration(
            labelText: 'Code or invite link',
            hintText: '7KQ2-M9XA',
            errorText: _error,
            errorMaxLines: 2,
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy || ref.watch(isOfflineProvider) ? null : _submit,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Find invite'),
        ),
      ],
    ),
  );
}

/// Reads the clipboard; overridden in tests.
final readClipboardProvider = Provider<Future<String?> Function()>(
  (ref) =>
      () async => (await Clipboard.getData(Clipboard.kTextPlain))?.text,
);

class _ClipboardChecked extends Notifier<bool> {
  @override
  bool build() => false;

  void mark() => state = true;
}

final _clipboardCheckedProvider = NotifierProvider<_ClipboardChecked, bool>(
  _ClipboardChecked.new,
);

/// Once per session, offers to use an invite code found on the clipboard
/// (spec UC-12: someone copied it from a chat before installing).
Future<void> offerClipboardInvite(BuildContext context, WidgetRef ref) async {
  if (ref.read(_clipboardCheckedProvider)) return;
  ref.read(_clipboardCheckedProvider.notifier).mark();
  final code = normaliseCode(await ref.read(readClipboardProvider)() ?? '');
  if (code == null || !context.mounted) return;
  final saved = ref.read(savedInviteCodesProvider).value ?? const [];
  if (saved.contains(code)) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 8),
      content: Text('Found invite code ${formatCode(code)}. Use it?'),
      action: SnackBarAction(
        label: 'Use',
        onPressed: () async {
          final message = await addInviteCode(ref, code);
          if (context.mounted) showAuthMessage(context, message);
        },
      ),
    ),
  );
}
