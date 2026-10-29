import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';

/// Shown to a minor whose parent withdrew consent (spec §7.3).
class AccountPausedScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthScaffold(
      title: 'Your account is paused',
      subtitle:
          'Your parent or guardian withdrew their consent. Your account and '
          'data will be deleted within 48 hours.',
      body: const Text(
        'If this is a mistake, ask them. They can’t undo it, but you can '
        'sign up again later with their consent.',
      ),
      primary: OutlinedButton(
        onPressed: ref.read(authServiceProvider).signOut,
        child: const Text('Sign out'),
      ),
    );
  }
}
