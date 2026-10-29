import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/auth/ui/dob_field.dart';
import 'package:roamio/features/consent/data/consent_service.dart';

final StreamProvider<List<LinkedChild>> _linkedChildrenProvider =
    StreamProvider.autoDispose<List<LinkedChild>>(
      (ref) => ref.watch(consentServiceProvider).linkedChildren(),
    );

/// The You tab. Profile and the privacy centre arrive in Tasks 34–35; for now
/// it holds Linked children (spec §7.3) and signing out.
class YouScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final children = ref.watch(_linkedChildrenProvider).value ?? const [];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          Text('You', style: text.displayLarge),
          const SizedBox(height: 8),
          Text(
            'Your profile and privacy centre are coming soon.',
            style: text.bodyLarge?.copyWith(color: RoamioColors.slate),
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text('Linked children', style: text.headlineSmall),
            const SizedBox(height: 8),
            for (final child in children) _LinkedChildTile(child: child),
          ],
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: ref.read(authServiceProvider).signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _LinkedChildTile extends ConsumerWidget {
  const new({required this.child});

  final LinkedChild child;

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Withdraw consent for ${child.name}?'),
        content: Text(
          '${child.name}’s account is paused right away and deleted, with '
          'their data, within 48 hours. This can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep consent'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (!(sure ?? false)) return;
    try {
      await ref.read(consentServiceProvider).withdraw(child.uid);
      if (context.mounted) {
        showAuthMessage(context, 'Consent withdrawn for ${child.name}.');
      }
    } on ConsentException catch (e) {
      if (context.mounted) showAuthMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final since = child.since;
    return Card(
      child: ListTile(
        title: Text(child.name),
        subtitle: Text(
          since == null
              ? 'Consent given'
              : 'Consent given ${formatDate(since)}',
        ),
        trailing: TextButton(
          onPressed: () => _withdraw(context, ref),
          child: const Text('Withdraw'),
        ),
      ),
    );
  }
}
