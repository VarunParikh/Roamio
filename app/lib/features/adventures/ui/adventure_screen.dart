import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/ui/adventure_card.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/invites/ui/invite_section.dart';
import 'package:roamio/features/squad/ui/squad_section.dart';
import 'package:roamio/features/tabs/ui/tabs_section.dart';

/// One adventure: the trip, invites, squad and tabs. Leads can edit it
/// (UC-10). Task 27 turns this into the full adventure page.
class AdventureScreen extends ConsumerWidget {
  const new({required this.adventureId, super.key});

  final String adventureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final adventures = ref.watch(myAdventuresProvider);
    final adventure = adventures.value
        ?.where((a) => a.id == adventureId)
        .firstOrNull;
    final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';
    final country = adventure == null
        ? null
        : ref.watch(countriesProvider).value?.byCode(adventure.countryCode);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          if (adventure != null && adventure.isLead(myUid))
            IconButton(
              tooltip: 'Edit adventure',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/adventures/$adventureId/edit'),
            ),
        ],
      ),
      body: SafeArea(
        child: adventure == null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (adventures.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      Text(
                        'This adventure isn’t available.',
                        textAlign: TextAlign.center,
                        style: text.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => context.go(AuthRoutes.home),
                        child: const Text('Back to Home'),
                      ),
                    ],
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  HeroAdventureCard(adventure: adventure),
                  const SizedBox(height: 24),
                  if (adventure.description.isNotEmpty) ...[
                    Text(adventure.description, style: text.bodyLarge),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Trip currency: ${adventure.baseCurrency}'
                    '${country == null ? '' : ' · ${country.landmark}'}',
                    style: text.bodyMedium?.copyWith(color: RoamioColors.slate),
                  ),
                  const SizedBox(height: 24),
                  InviteSection(adventure: adventure, myUid: myUid),
                  const SizedBox(height: 24),
                  SquadSection(adventure: adventure, myUid: myUid),
                  const SizedBox(height: 24),
                  TabsSection(adventure: adventure, myUid: myUid),
                ],
              ),
      ),
    );
  }
}
