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

/// The big card for the current or next adventure (UC-5). Until banners
/// arrive (Task 16) it shows the country's flag on a dark gradient.
class HeroAdventureCard extends ConsumerWidget {
  const new({required this.adventure, super.key});

  final Adventure adventure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final country = ref
        .watch(countriesProvider)
        .value
        ?.byCode(adventure.countryCode);
    final place = [
      if (adventure.city.isNotEmpty) adventure.city,
      ?country?.name,
    ].join(', ');
    return Semantics(
      button: true,
      label: '${adventure.name}, ${statusLabel(adventure, today)}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RoamioRadii.lg),
        child: SizedBox(
          height: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AdventureBanner(
                countryCode: adventure.countryCode,
                flag: country?.flag ?? '🌍',
                customUrl: adventure.bannerUrl,
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => context.push('/adventures/${adventure.id}'),
                ),
              ),
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: RoamioColors.chartreuse,
                          borderRadius: BorderRadius.circular(RoamioRadii.full),
                        ),
                        child: Text(
                          statusLabel(adventure, today).toUpperCase(),
                          style: text.labelSmall,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        adventure.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.headlineLarge?.copyWith(
                          color: RoamioColors.surface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          formatDateRange(
                            adventure.startDate,
                            adventure.endDate,
                          ),
                          if (place.isNotEmpty) place,
                        ].join(' · '),
                        style: text.bodyMedium?.copyWith(
                          color: RoamioColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: _HeroWeather(
                  city: adventure.city.isNotEmpty
                      ? adventure.city
                      : country?.name ?? '',
                  countryCode: adventure.countryCode,
                ),
              ),
              Positioned(
                right: 12,
                bottom: 8,
                child: BannerCredit(
                  countryCode: adventure.countryCode,
                  customUrl: adventure.bannerUrl,
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

/// "☀️ 30°C" in the Hero card's corner; nothing while loading or when the
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
