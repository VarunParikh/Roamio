import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/data/activity_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_format.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/banners/ui/adventure_banner.dart';
import 'package:roamio/features/squad/ui/person.dart';
import 'package:roamio/features/tabs/ui/tabs_section.dart';

/// A banner card for a trip that isn't the big one on Home (spec UC-5).
class OtherTripCard extends ConsumerWidget {
  const new({required this.adventure, this.showDates = true, super.key});

  final Adventure adventure;

  /// Off when the date already sits beside the card.
  final bool showDates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final dates = [
      if (showDates) formatDateRange(adventure.startDate, adventure.endDate),
      heroCountdown(adventure, ref.watch(todayProvider)),
    ].join(' · ');
    final flag = ref
        .watch(countriesProvider)
        .value
        ?.byCode(adventure.countryCode)
        ?.flag;
    void open() => context.push('/adventures/${adventure.id}');
    return Semantics(
      container: true,
      button: true,
      label: '${adventure.name}, $dates',
      onTap: open,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RoamioRadii.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 130),
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              Positioned.fill(
                child: AdventureBanner(
                  countryCode: adventure.countryCode,
                  flag: flag ?? '🌍',
                  customUrl: adventure.bannerUrl,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            adventure.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.headlineSmall?.copyWith(
                              color: RoamioColors.surface,
                            ),
                          ),
                          Text(
                            dates,
                            style: text.bodySmall?.copyWith(
                              color: RoamioColors.surface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: RoamioColors.surface,
                      foregroundColor: RoamioColors.ink,
                      child: Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(onTap: open),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An upcoming trip's card, with its start date beside it.
class UpcomingTrip extends StatelessWidget {
  const new({required this.adventure, super.key});

  final Adventure adventure;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final start = adventure.startDate;
    // "Wed, 4 Nov 2026".
    final [weekday, day, month, year] = formatDay(start).split(RegExp('[, ]+'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            key: ValueKey('date-${adventure.id}'),
            width: 64,
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day, style: text.headlineMedium),
                  Text('$month $year', style: text.bodySmall),
                  Text(
                    weekday.toUpperCase(),
                    style: text.labelSmall?.copyWith(color: RoamioColors.slate),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OtherTripCard(adventure: adventure, showDates: false),
          ),
        ],
      ),
    );
  }
}

/// One row with the newest event across [trips] (current and upcoming), opening
/// that trip's Activity (spec UC-5). Each trip costs one record to read. Names
/// a tab only if this person can read it, so private tabs stay private.
class RecentActivity extends ConsumerWidget {
  const new({required this.trips, super.key});

  final List<Adventure> trips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Adventure? trip;
    ActivityEntry? newest;
    for (final a in trips) {
      final e = ref.watch(latestActivityProvider(a.id)).value;
      if (e == null) continue;
      // The server hasn't stamped something just logged, so it's the newest.
      final isNewer =
          newest == null ||
          e.createdAt == null ||
          (newest.createdAt != null && e.createdAt!.isAfter(newest.createdAt!));
      if (isNewer) {
        newest = e;
        trip = a;
      }
    }
    if (newest == null || trip == null) return const SizedBox.shrink();
    final adventure = trip;
    final actor = newest.actorUid;
    // Only the trip shown has its squad looked up.
    final people = squadWithoutTabs(ref, adventure);
    final line = describeActivity(
      newest,
      myUid: ref.watch(sessionFactsProvider).value?.uid ?? '',
      who: (id) => people[id]?.name ?? 'Someone',
    );
    if (line == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    void open() => context.push('/adventures/${adventure.id}/activity');
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Recent activity', style: text.headlineSmall),
          const SizedBox(height: 8),
          Semantics(
            key: const ValueKey('recent-activity'),
            container: true,
            button: true,
            label: '$line, ${adventure.name}',
            onTap: open,
            excludeSemantics: true,
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(RoamioRadii.md),
                onTap: open,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      PersonAvatar(uid: actor, person: people[actor]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line, style: text.titleSmall),
                            Text(
                              '🎒 ${adventure.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                color: RoamioColors.slate,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: RoamioColors.slate,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
