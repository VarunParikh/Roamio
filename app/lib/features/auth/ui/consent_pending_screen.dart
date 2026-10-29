import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';

/// Where 13–17 year olds wait for a parent or guardian (spec §7.1).
/// Task 12 adds the parent-email form and resend controls here.
class ConsentPendingScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthScaffold(
      title: 'Almost there! 🙌',
      subtitle:
          'Because you’re under 18, a parent or guardian needs to say yes '
          'before you can start using Roamio.',
      body: const Text(
        'Next you’ll add their email address and we’ll send them a link. '
        'This part of Roamio is still being built.',
      ),
      primary: OutlinedButton(
        onPressed: ref.read(authServiceProvider).signOut,
        child: const Text('Sign out'),
      ),
    );
  }
}
