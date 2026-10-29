import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_card.dart';
import 'package:roamio/features/auth/data/auth_service.dart';

const newAdventureRoute = '/adventures/new';

/// Home (UC-5, UC-6): greeting, the hero adventure, what's coming up and
/// what's past. With nothing yet, one pulsing New Adventure button.
class HomeScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final first = ref
        .read(authServiceProvider)
        .displayName
        ?.trim()
        .split(' ')
        .first;
    final greeting = first == null || first.isEmpty
        ? 'Hey there 👋'
        : 'Hey $first 👋';
    final adventures = ref.watch(myAdventuresProvider);
    final sections = homeSectionsFor(
      adventures.value ?? const [],
      ref.watch(todayProvider),
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          Text(greeting, style: text.displayLarge),
          const SizedBox(height: 24),
          if (adventures.hasError)
            _Message(
              text: 'We couldn’t load your adventures.',
              action: OutlinedButton(
                onPressed: () => ref.invalidate(myAdventuresProvider),
                child: const Text('Try again'),
              ),
            )
          else if (adventures.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (sections.isEmpty)
            _Message(
              text: 'No adventures yet. Start one and invite your squad.',
              action: PrimaryButton(
                label: 'New Adventure',
                icon: Icons.add,
                pulse: true,
                onPressed: () => context.push(newAdventureRoute),
              ),
            )
          else ...[
            if (sections.hero != null)
              HeroAdventureCard(adventure: sections.hero!),
            if (sections.upcoming.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Coming up', style: text.headlineSmall),
              const SizedBox(height: 8),
              for (final a in sections.upcoming) AdventureTile(adventure: a),
            ],
            if (sections.past.isNotEmpty) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Past adventures (${sections.past.length})',
                  style: text.headlineSmall,
                ),
                children: [
                  for (final a in sections.past) AdventureTile(adventure: a),
                ],
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.push(newAdventureRoute),
              icon: const Icon(Icons.add),
              label: const Text('New adventure'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const new({required this.text, required this.action});

  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 40),
      const Text(
        '🧭',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 64),
      ),
      const SizedBox(height: 16),
      Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: RoamioColors.slate),
      ),
      const SizedBox(height: 24),
      action,
    ],
  );
}
