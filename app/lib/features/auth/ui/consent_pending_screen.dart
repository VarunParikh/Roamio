import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/auth/ui/email_sign_in_screen.dart';
import 'package:roamio/features/consent/data/consent_service.dart';

final StreamProvider<MyConsentRequest?> _myRequestProvider =
    StreamProvider.autoDispose<MyConsentRequest?>(
      (ref) => ref.watch(consentServiceProvider).myRequest(),
    );

const _relationships = ['Mother', 'Father', 'Guardian'];

/// Where 13–17 year olds ask a parent or guardian for consent and wait for
/// their answer (spec §7.1 steps 2–3).
class ConsentPendingScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ConsentPendingScreen> createState() =>
      _ConsentPendingScreenState();
}

class _ConsentPendingScreenState extends ConsumerState<ConsentPendingScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  String _relationship = _relationships.first;
  bool _editing = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send(String parentEmail) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(consentServiceProvider)
          .requestConsent(
            parentEmail: parentEmail.trim(),
            relationship: _relationship.toLowerCase(),
          );
      if (!mounted) return;
      setState(() => _editing = false);
      showAuthMessage(context, 'Sent! Ask them to check their inbox.');
    } on ConsentException catch (e) {
      if (mounted) showAuthMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(_myRequestProvider).value;
    final waiting = request?.status == 'requested' && !_editing;
    final signOut = TextButton(
      onPressed: _busy ? null : ref.read(authServiceProvider).signOut,
      child: const Text('Sign out'),
    );

    if (waiting) {
      return AuthScaffold(
        title: 'Waiting for a yes ⏳',
        subtitle:
            'We emailed ${request!.parentEmail}. Once they say yes, '
            'Roamio opens up for you. The link works for 7 days.',
        body: Text(
          'Nothing there? Ask them to check spam, or send it again.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: RoamioColors.slate),
        ),
        primary: PrimaryButton(
          label: 'Send the email again',
          busy: _busy,
          onPressed: () => _send(request.parentEmail),
        ),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _editing = true;
                      _email.text = request.parentEmail;
                    }),
              child: const Text('Use a different email'),
            ),
            signOut,
          ],
        ),
      );
    }

    return AuthScaffold(
      title: 'Almost there! 🙌',
      subtitle:
          'Because you’re under 18, a parent or guardian needs to say yes '
          'before you can use Roamio. We’ll email them a link.',
      body: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: 'Their email address',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => emailMessage(v ?? ''),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final r in _relationships)
                  ChoiceChip(
                    label: Text(r),
                    selected: _relationship == r,
                    onSelected: (_) => setState(() => _relationship = r),
                  ),
              ],
            ),
          ],
        ),
      ),
      primary: PrimaryButton(
        label: 'Send request',
        busy: _busy,
        onPressed: () async {
          if (_form.currentState!.validate()) await _send(_email.text);
        },
      ),
      footer: signOut,
    );
  }
}
