import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/consent/data/consent_service.dart';

/// A parent opens their consent link here (spec §7.1 steps 4–5).
class ParentConsentScreen extends ConsumerStatefulWidget {
  const new({required this.childUid, required this.token, super.key});

  final String childUid;
  final String token;

  @override
  ConsumerState<ParentConsentScreen> createState() =>
      _ParentConsentScreenState();
}

class _ParentConsentScreenState extends ConsumerState<ParentConsentScreen> {
  late final Future<ConsentDetails> _details = ref
      .read(consentServiceProvider)
      .describe(childUid: widget.childUid, token: widget.token);
  bool _declared = false;
  bool _busy = false;
  String? _outcome;

  Future<void> _decide({required bool grant}) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(consentServiceProvider)
          .decide(childUid: widget.childUid, token: widget.token, grant: grant);
      if (mounted) setState(() => _outcome = grant ? 'granted' : 'declined');
    } on ConsentException catch (e) {
      if (mounted) showAuthMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDecline(String child) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Say no to $child?'),
        content: Text(
          '$child’s Roamio account and everything in it will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go back'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (sure ?? false) await _decide(grant: false);
  }

  @override
  Widget build(BuildContext context) {
    final home = OutlinedButton(
      onPressed: () => context.go(AuthRoutes.home),
      child: const Text('Go to Roamio'),
    );
    return FutureBuilder<ConsentDetails>(
      future: _details,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          return AuthScaffold(
            title: 'This link can’t be used',
            subtitle: error is ConsentException
                ? error.message
                : 'Something went wrong. Please try again.',
            body: const Text(
              'If your child asked again, use the link in the newest email.',
            ),
            primary: home,
          );
        }
        final details = snapshot.data;
        if (details == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final child = details.childFirstName;
        if (_outcome != null) {
          return AuthScaffold(
            title: _outcome == 'granted' ? 'All set 🎉' : 'Done',
            subtitle: _outcome == 'granted'
                ? '$child can now use Roamio. You can withdraw consent any '
                      'time from You → Linked children.'
                : 'We’ve deleted $child’s account and let them know.',
            body: const SizedBox.shrink(),
            primary: home,
          );
        }
        return AuthScaffold(
          title: '$child wants to use Roamio',
          subtitle:
              '$child says you’re their ${details.relationship}. They’re '
              'under 18, so they need your consent first.',
          body: _ChildNotice(
            child: child,
            declared: _declared,
            onDeclared: (v) => setState(() => _declared = v),
          ),
          primary: PrimaryButton(
            label: 'I give consent',
            busy: _busy,
            onPressed: _declared ? () => _decide(grant: true) : null,
          ),
          footer: TextButton(
            onPressed: _busy ? null : () => _confirmDecline(child),
            child: const Text('Decline'),
          ),
        );
      },
    );
  }
}

/// The child-specific notice (spec §7.1 step 5, §7.2).
class _ChildNotice extends StatelessWidget {
  const new({
    required this.child,
    required this.declared,
    required this.onDeclared,
  });

  final String child;
  final bool declared;
  final ValueChanged<bool> onDeclared;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What Roamio collects', style: text.headlineSmall),
        const SizedBox(height: 8),
        Text(
          '• $child’s name, email and date of birth.\n'
          '• Trips, shared expenses, receipts and photos they add.\n\n'
          'How we protect under-18s\n'
          '• No tracking, analytics or ads.\n'
          '• No location tagging.\n'
          '• Their personal budget stays private.\n'
          '• Data is stored in India.\n\n'
          'You can withdraw consent at any time from You → Linked children; '
          'their account is then deleted within 48 hours.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: declared, onChanged: (v) => onDeclared(v ?? false)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'I am $child’s parent or lawful guardian. I understand that '
                  'falsely claiming this is an offence.',
                  style: text.bodyMedium?.copyWith(color: RoamioColors.ink),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
