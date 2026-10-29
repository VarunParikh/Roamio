import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_format.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/banners/ui/adventure_banner.dart';
import 'package:roamio/features/invites/ui/invite_section.dart';
import 'package:roamio/features/squad/ui/squad_section.dart';
import 'package:roamio/features/sync/sync_banner.dart';
import 'package:roamio/features/tabs/ui/tabs_section.dart';

/// One adventure (spec UC-23): the banner, with a sheet that scrolls up
/// over it holding the trip, its tabs by day, the invite and the squad.
/// Add tab floats at the bottom.
class AdventurePage extends ConsumerWidget {
  const new({required this.adventureId, super.key});

  final String adventureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adventures = ref.watch(myAdventuresProvider);
    final adventure = adventures.value
        ?.where((a) => a.id == adventureId)
        .firstOrNull;
    if (adventure == null) {
      return _Unavailable(loading: adventures.isLoading);
    }
    final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';
    final open = adventure.tabsOpenOn(ref.watch(todayProvider));
    final banner = MediaQuery.sizeOf(context).height * 0.34;

    return Scaffold(
      body: Stack(
        children: [
          SizedBox(
            height: banner + 32,
            width: double.infinity,
            child: AdventureBanner(
              countryCode: adventure.countryCode,
              flag:
                  ref
                      .watch(countriesProvider)
                      .value
                      ?.byCode(adventure.countryCode)
                      ?.flag ??
                  '🌍',
              customUrl: adventure.bannerUrl,
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.66,
            minChildSize: 0.66,
            snap: true,
            builder: (context, controller) => DecoratedBox(
              decoration: const BoxDecoration(
                color: RoamioColors.canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x120F1115),
                    blurRadius: 40,
                    offset: Offset(0, -12),
                  ),
                ],
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  const _Handle(),
                  const SyncBanner(),
                  _TripHeader(adventure: adventure),
                  const SizedBox(height: 24),
                  TabsSection(adventure: adventure, myUid: myUid),
                  const SizedBox(height: 32),
                  InviteSection(adventure: adventure, myUid: myUid),
                  const SizedBox(height: 24),
                  SquadSection(adventure: adventure, myUid: myUid),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(AuthRoutes.home),
                  ),
                  const Spacer(),
                  if (adventure.isLead(myUid))
                    IconButton.filledTonal(
                      tooltip: 'Edit adventure',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () =>
                          context.push('/adventures/$adventureId/edit'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(180, 56),
          shape: const StadiumBorder(),
        ),
        onPressed: open
            ? () => context.push('/adventures/$adventureId/tabs/new')
            : null,
        icon: const CircleAvatar(
          radius: 14,
          backgroundColor: RoamioColors.chartreuse,
          foregroundColor: RoamioColors.ink,
          child: Icon(Icons.add, size: 18),
        ),
        label: const Text('Add tab'),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: RoamioColors.hairline,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _TripHeader extends ConsumerWidget {
  const new({required this.adventure});

  final Adventure adventure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final country = ref
        .watch(countriesProvider)
        .value
        ?.byCode(adventure.countryCode);
    final slate = text.bodyMedium?.copyWith(color: RoamioColors.slate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(adventure.name, style: text.headlineLarge),
        const SizedBox(height: 4),
        Text(
          '${formatDateRange(adventure.startDate, adventure.endDate)} · '
          '${statusLabel(adventure, ref.watch(todayProvider))}',
          style: slate,
        ),
        if (adventure.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(adventure.description, style: text.bodyLarge),
        ],
        const SizedBox(height: 8),
        Text(
          'Trip currency: ${adventure.baseCurrency}'
          '${country == null ? '' : ' · ${country.landmark}'}',
          style: slate,
        ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const new({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(backgroundColor: Colors.transparent),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            Text(
              'This adventure isn’t available.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.go(AuthRoutes.home),
              child: const Text('Back to Home'),
            ),
          ],
        ],
      ),
    ),
  );
}
