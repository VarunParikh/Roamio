import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/profile/data/profile_service.dart';
import 'package:roamio/features/profile/ui/character_picker.dart';

/// Offers a new account a character, once (spec UC-28). Not now is saved on
/// the profile, so it isn't asked again; the You page can still change it.
class CharacterPrompt extends ConsumerWidget {
  const new({super.key});

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final id = await showCharacterPicker(context);
    if (id != null) await ref.read(profileServiceProvider).setCharacter(id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileStreamProvider).value;
    if (profile == null || profile.characterOffered) {
      return const SizedBox.shrink();
    }
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pick your character', style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Your squad sees it next to your name.',
                style: text.bodyMedium?.copyWith(color: RoamioColors.slate),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _choose(context, ref),
                      child: const Text('Choose'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () =>
                        ref.read(profileServiceProvider).setCharacter(null),
                    child: const Text('Not now'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
