import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/consent/data/consent_service.dart';

/// Someone who turned 18 accepts the adult privacy notice (spec §7.4).
class ConfirmAdultScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ConfirmAdultScreen> createState() => _ConfirmAdultScreenState();
}

class _ConfirmAdultScreenState extends ConsumerState<ConfirmAdultScreen> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await ref.read(consentServiceProvider).acceptAdultNotice();
    } on ConsentException catch (e) {
      if (mounted) showAuthMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Happy 18th! 🎂',
      subtitle:
          'You now manage your own Roamio account, so your parent or '
          'guardian’s consent is no longer needed.',
      body: const Text(
        'As an adult account:\n'
        '• You can choose to tag tabs with a location.\n'
        '• You decide your own privacy settings in the You tab.\n'
        '• Your data is still stored in India, and you can download or '
        'delete it any time.\n\n'
        'Please accept the adult privacy notice to carry on.',
      ),
      primary: PrimaryButton(
        label: 'Accept and continue',
        busy: _busy,
        onPressed: _accept,
      ),
      footer: TextButton(
        onPressed: _busy ? null : ref.read(authServiceProvider).signOut,
        child: const Text('Sign out'),
      ),
    );
  }
}
