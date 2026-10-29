import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/config/flavor.dart';
import 'package:roamio/core/privacy/privacy_policy.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/banners/data/banner_service.dart';
import 'package:roamio/features/consent/data/consent_service.dart';
import 'package:roamio/features/profile/data/privacy_service.dart';
import 'package:roamio/features/profile/data/profile_service.dart';
import 'package:roamio/features/profile/ui/consent_switches.dart';
import 'package:roamio/features/splits/ui/export_sheet.dart';
import 'package:roamio/features/sync/sync_controller.dart';
import 'package:share_plus/share_plus.dart';

const privacyCentreRoute = '/privacy';

/// PLACEHOLDER until the owner picks the grievance alias (spec §17.3, Task 40).
const grievanceEmail = 'grievance@roamio.example';

const _needsConnection = 'Needs a connection.';

/// What a parent is told before deleting: their children's accounts stay.
String _childrenStay(List<LinkedChild> children) {
  final names = children.map((c) => c.name).join(' and ');
  return children.length == 1
      ? '$names keeps their account. To close it, withdraw consent on the '
            'You page first.'
      : '$names keep their accounts. To close them, withdraw consent on '
            'the You page first.';
}

final StreamProvider<List<LinkedChild>> _childrenProvider =
    StreamProvider.autoDispose<List<LinkedChild>>(
      (ref) => ref.watch(consentServiceProvider).linkedChildren(),
    );

/// The Privacy centre (spec UC-29, §8): download or delete your data,
/// correct it, nominate someone, raise a concern, and choose per purpose.
/// Parents can also download each linked child's data (§7.3).
class PrivacyCentreScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<PrivacyCentreScreen> createState() =>
      _PrivacyCentreScreenState();
}

class _PrivacyCentreScreenState extends ConsumerState<PrivacyCentreScreen> {
  /// Whose download is running: `me`, a child's uid, or null.
  String? _downloading;
  String? _downloadNote;
  bool _deleting = false;
  String? _deleteError;

  Future<void> _download({LinkedChild? child}) async {
    setState(() {
      _downloading = child?.uid ?? 'me';
      _downloadNote = null;
    });
    final owner = child == null ? '' : '${child.name}’s ';
    try {
      final files = await ref
          .read(privacyServiceProvider)
          .downloadData(childUid: child?.uid);
      var part = 0;
      final names = [
        for (final f in files)
          if (f.kind == 'data')
            '${owner}Roamio data.json'
          else
            '${owner}Roamio photos ${++part}.zip',
      ];
      await ref.read(shareFilesProvider)([
        for (final (i, f) in files.indexed)
          XFile.fromData(f.bytes, mimeType: f.mimeType, name: names[i]),
      ], names);
      _downloadNote = 'Your files are ready. Save them somewhere safe.';
    } on PrivacyException catch (e) {
      _downloadNote = e.message;
    } on Exception {
      _downloadNote = 'Couldn’t share the files. Please try again.';
    }
    if (mounted) setState(() => _downloading = null);
  }

  Future<void> _delete(List<LinkedChild> children) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: Text(
          'Your profile, photos and budgets are deleted. Tabs you were on '
          'stay with your squads and show “Deleted user”, so everyone’s '
          'balances stay right. This can’t be undone.'
          '${children.isEmpty ? '' : '\n\n${_childrenStay(children)}'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep my account'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: RoamioColors.coral),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(sure ?? false) || !mounted) return;
    setState(() {
      _deleting = true;
      _deleteError = null;
    });
    try {
      // The dialog above is the parent's confirmation (spec §7.5).
      await ref
          .read(privacyServiceProvider)
          .deleteAccount(confirmLinkedChildren: children.isNotEmpty);
      await ref.read(authServiceProvider).signOut();
    } on PrivacyException catch (e) {
      if (mounted) setState(() => _deleteError = e.message);
    }
    if (mounted) setState(() => _deleting = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final offline = ref.watch(isOfflineProvider);
    final children = ref.watch(_childrenProvider).value ?? const [];
    final busy = _downloading != null || _deleting;
    final muted = text.bodyMedium?.copyWith(color: RoamioColors.slate);

    Widget section(String title, String body, [List<Widget> more = const []]) =>
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.headlineSmall),
              const SizedBox(height: 8),
              Text(body, style: muted),
              ...more,
            ],
          ),
        );

    return AuthScaffold(
      showBack: true,
      title: 'Privacy centre',
      subtitle:
          'Everything Roamio keeps about you, and what you can do with it.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Download my data gives you a file of everything we keep about '
            'you, plus your photos as zip files.',
            style: muted,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              // The published notice (docs/PRIVACY_NOTICE.md) on Hosting.
              onPressed: () =>
                  ref.read(openLinkProvider)(Uri.parse('$siteUrl/privacy/')),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Read the privacy notice'),
            ),
          ),
          if (_downloadNote != null) ...[
            const SizedBox(height: 8),
            Text(_downloadNote!, style: text.bodyMedium),
          ],
          if (offline) ...[
            const SizedBox(height: 8),
            Text(_needsConnection, style: muted),
          ],
          if (children.isNotEmpty)
            section(
              'Linked children',
              'Download what Roamio keeps about a child you gave consent for.',
              [
                for (final child in children)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton(
                      onPressed: busy || offline
                          ? null
                          : () => _download(child: child),
                      child: Text('Download ${child.name}’s data'),
                    ),
                  ),
              ],
            ),
          section(
            'Your choices',
            'Turn each one on or off at any time.',
            const [ConsentSwitches()],
          ),
          section(
            'Correct your data',
            'Change your name, photo and description on the You page. '
                'Your date of birth can only be fixed by writing to us.',
          ),
          const _NomineeSection(),
          section(
            'Raise a concern',
            'Write to our grievance officer at $grievanceEmail. We reply '
                'within 7 days.',
            [
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: grievanceEmail),
                  );
                  if (context.mounted) {
                    showAuthMessage(context, 'Email address copied.');
                  }
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy email address'),
              ),
            ],
          ),
          section(
            'Delete your account',
            'Removes your profile, photos and budgets. If you lead a squad '
                'with others in it, make someone else leader first.',
            [
              if (_deleteError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _deleteError!,
                  style: text.bodyMedium?.copyWith(color: RoamioColors.coral),
                ),
              ],
              if (offline) ...[
                const SizedBox(height: 8),
                Text(_needsConnection, style: muted),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: busy || offline ? null : () => _delete(children),
                style: OutlinedButton.styleFrom(
                  foregroundColor: RoamioColors.coral,
                ),
                child: const Text('Delete my account'),
              ),
            ],
          ),
        ],
      ),
      primary: PrimaryButton(
        label: 'Download my data',
        busy: _downloading == 'me',
        onPressed: busy || offline ? null : _download,
      ),
    );
  }
}

/// Nominate a person (spec UC-29, DPDP §14). Under-18s don't nominate: a
/// parent or guardian already acts for them (§7).
class _NomineeSection extends ConsumerWidget {
  const new();

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final chosen = await showDialog<Nominee>(
      context: context,
      builder: (_) => _NomineeDialog(current: ref.read(nomineeProvider).value),
    );
    if (chosen != null) {
      await ref.read(profileServiceProvider).setNominee(chosen);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(color: RoamioColors.slate);
    final isMinor = ref.watch(privacyPolicyProvider).isMinor;
    final nominee = ref.watch(nomineeProvider).value;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nominate a person', style: text.headlineSmall),
          const SizedBox(height: 8),
          if (isMinor)
            Text(
              'Your parent or guardian can use these rights for you, so '
              'there’s no one to nominate.',
              style: muted,
            )
          else ...[
            Text(
              'Choose someone to use these rights for you if you can’t. '
              'We’ll confirm with you before they do anything.',
              style: muted,
            ),
            const SizedBox(height: 8),
            Text(
              nominee == null
                  ? 'No one yet.'
                  : 'Nominated: ${nominee.name} (${nominee.email})',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => _choose(context, ref),
                  child: Text(nominee == null ? 'Choose a person' : 'Change'),
                ),
                if (nominee != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: () =>
                        ref.read(profileServiceProvider).setNominee(null),
                    child: const Text('Remove'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class _NomineeDialog extends StatefulWidget {
  const new({this.current});

  final Nominee? current;

  @override
  State<_NomineeDialog> createState() => _NomineeDialogState();
}

class _NomineeDialogState extends State<_NomineeDialog> {
  late final _name = TextEditingController(text: widget.current?.name);
  late final _email = TextEditingController(text: widget.current?.email);
  String? _nameError;
  String? _emailError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final email = _email.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Add their name.' : null;
      _emailError = _emailPattern.hasMatch(email)
          ? null
          : 'Check the email address.';
    });
    if (_nameError == null && _emailError == null) {
      Navigator.pop(context, Nominee(name: name, email: email));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nominate a person'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [LengthLimitingTextInputFormatter(80)],
          decoration: InputDecoration(
            labelText: 'Their name',
            errorText: _nameError,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          inputFormatters: [LengthLimitingTextInputFormatter(254)],
          decoration: InputDecoration(
            labelText: 'Their email',
            errorText: _emailError,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}
