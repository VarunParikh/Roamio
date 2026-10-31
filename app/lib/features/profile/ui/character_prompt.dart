import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/profile/data/profile_service.dart';
import 'package:roamio/features/profile/domain/characters.dart';
import 'package:roamio/features/profile/ui/character_avatar.dart';
import 'package:roamio/features/profile/ui/character_picker.dart';

/// Whether [CharacterPrompt] has anything to say.
bool characterPromptNeeded(WidgetRef ref) {
  final profile = ref.watch(profileStreamProvider).value;
  return profile != null && !profile.characterOffered;
}

/// Shows a new account the character it was given, and offers a change, once
/// (spec UC-28). Keep it is saved on the profile, so it isn't asked again; the
/// You page can still change it.
class CharacterPrompt extends ConsumerWidget {
  const new({super.key});

  Future<void> _change(BuildContext context, WidgetRef ref, String uid) async {
    final id = await showCharacterPicker(
      context,
      current: defaultCharacterFor(uid).id,
    );
    if (id != null) await ref.read(profileServiceProvider).setCharacter(id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(sessionFactsProvider).value?.uid ?? '';
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CharacterAvatar(uid: uid, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('We picked this for you', style: text.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Your squad sees it next to your name. Change it?',
                        style: text.bodyMedium?.copyWith(
                          color: RoamioColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _change(context, ref, uid),
                    child: const Text('Change'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () =>
                      ref.read(profileServiceProvider).setCharacter(null),
                  child: const Text('Keep it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
