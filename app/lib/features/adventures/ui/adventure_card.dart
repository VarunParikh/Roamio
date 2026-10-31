import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_format.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/banners/ui/adventure_banner.dart';
import 'package:roamio/features/home/data/weather_provider.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/squad/ui/person.dart';

/// The big card for the current or next adventure (spec UC-5): tap it to
/// open the adventure. It grows with its text, so nothing overflows.
class HeroAdventureCard extends ConsumerWidget {
  const new({required this.adventure, super.key});

  final Adventure adventure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';
    final country = ref
        .watch(countriesProvider)
        .value
        ?.byCode(adventure.countryCode);
    // Looked up here rather than with squadPeople, which reads the tabs.
    final members =
        ref.watch(squadPeopleProvider(adventure.memberUids.join(','))).value ??
        const <String, SquadPerson>{};
    final pals = ref.watch(palsProvider(adventure.id)).value ?? const <Pal>[];
    final badge = heroBadge(adventure, today);
    final countdown = heroCountdown(adventure, today);
    return Semantics(
      button: true,
      label: '${adventure.name}, $badge, $countdown',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RoamioRadii.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 260),
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              Positioned.fill(
                child: AdventureBanner(
                  countryCode: adventure.countryCode,
                  flag: country?.flag ?? '🌍',
                  customUrl: adventure.bannerUrl,
                ),
              ),
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => context.push('/adventures/${adventure.id}'),
                  ),
                ),
              ),
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: RoamioColors.chartreuse,
                        borderRadius: BorderRadius.circular(RoamioRadii.full),
                      ),
                      child: Text(badge.toUpperCase(), style: text.labelSmall),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 64, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IgnorePointer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            adventure.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.headlineLarge?.copyWith(
                              color: RoamioColors.surface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                [
                                  formatDateRange(
                                    adventure.startDate,
                                    adventure.endDate,
                                  ),
                                  countdown,
                                ].join(' · '),
                                style: text.bodyMedium?.copyWith(
                                  color: RoamioColors.surface,
                                ),
                              ),
                              _HeroWeather(
                                city: adventure.city.isNotEmpty
                                    ? adventure.city
                                    : country?.name ?? '',
                                countryCode: adventure.countryCode,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: IgnorePointer(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: PeoplePictures(
                                ids: [
                                  ...adventure.memberUids,
                                  for (final p in pals) p.id,
                                ],
                                people: {
                                  ...members,
                                  for (final p in pals)
                                    p.id: SquadPerson(
                                      name: p.nickname,
                                      characterId: p.characterId,
                                    ),
                                },
                                firstUid: myUid,
                                radius: 16,
                                label: 'Your squad',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // White, so Home keeps a single chartreuse primary.
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            backgroundColor: RoamioColors.surface,
                            foregroundColor: RoamioColors.ink,
                          ),
                          onPressed: () => context.push(
                            '/adventures/${adventure.id}/tabs/new',
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Add tab'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    BannerCredit(
                      countryCode: adventure.countryCode,
                      customUrl: adventure.bannerUrl,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact row for the upcoming and past lists.
class AdventureTile extends ConsumerWidget {
  const new({required this.adventure, super.key});

  final Adventure adventure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final flag = ref
        .watch(countriesProvider)
        .value
        ?.byCode(adventure.countryCode)
        ?.flag;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Text(flag ?? '🌍', style: const TextStyle(fontSize: 28)),
        title: Text(
          adventure.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${formatDateRange(adventure.startDate, adventure.endDate)} · '
          '${statusLabel(adventure, today)}',
        ),
        trailing: const Icon(Icons.arrow_outward_rounded),
        onTap: () => context.push('/adventures/${adventure.id}'),
      ),
    );
  }
}

/// "☀️ 30°C" beside the Hero card's dates; nothing while loading or when the
/// weather is unavailable (spec UC-7).
class _HeroWeather extends ConsumerWidget {
  const new({required this.city, required this.countryCode});

  final String city;
  final String countryCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (city.isEmpty) return const SizedBox.shrink();
    final weather = ref.watch(heroWeatherProvider((city, countryCode))).value;
    if (weather == null) return const SizedBox.shrink();
    return Semantics(
      label: '${weather.label}, ${weather.temperatureC} degrees',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: RoamioColors.ink.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(RoamioRadii.full),
          ),
          child: Text(
            '${weather.emoji} ${weather.temperatureC}°C',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: RoamioColors.surface),
          ),
        ),
      ),
    );
  }
}
