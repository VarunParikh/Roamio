import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/router/app_router.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_card.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/banners/ui/banner_preloader.dart';
import 'package:roamio/features/home/ui/first_screen_cards.dart';
import 'package:roamio/features/home/ui/needs_you.dart';
import 'package:roamio/features/home/ui/other_trips.dart';
import 'package:roamio/features/invites/ui/invites_on_home.dart';
import 'package:roamio/features/notifications/ui/notification_prompt.dart';
import 'package:roamio/features/profile/data/profile_service.dart';
import 'package:roamio/features/profile/ui/character_avatar.dart';
import 'package:roamio/features/sync/sync_banner.dart';

const newAdventureRoute = '/adventures/new';

/// Home (UC-5, UC-6): greeting, the adventure card, what needs you, what's
/// coming up and what's past. With nothing ahead, the image card instead.
class HomeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// The first name on the greeting: the profile's name, so a rename shows at
/// once; the sign-in name until the profile loads.
final greetingNameProvider = Provider<String?>((ref) {
  final name =
      ref.watch(profileStreamProvider).value?.name ??
      ref.watch(authServiceProvider).displayName;
  return name?.trim().split(' ').first;
});

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => offerClipboardInvite(context, ref),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final first = ref.watch(greetingNameProvider);
    final greeting = first == null || first.isEmpty
        ? 'Hey there 👋'
        : 'Hey $first 👋';
    final profile = ref.watch(profileStreamProvider).value;
    final adventures = ref.watch(myAdventuresProvider);
    final sections = homeSectionsFor(
      adventures.value ?? const [],
      ref.watch(todayProvider),
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          Row(
            children: [
              Expanded(child: Text(greeting, style: text.displayLarge)),
              IconButton(
                tooltip: 'Your profile',
                padding: EdgeInsets.zero,
                icon: CharacterAvatar(
                  uid: ref.watch(sessionFactsProvider).value?.uid ?? '',
                  characterId: profile?.characterId,
                  loading: profile == null,
                  radius: 22,
                ),
                onPressed: () => context.go(Routes.you),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SyncBanner(),
          const PushIdRefresher(),
          const BannerPreloader(),
          if (adventures.hasError) ...[
            Text(
              'We couldn’t load your adventures.',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: RoamioColors.slate),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref.invalidate(myAdventuresProvider),
              child: const Text('Try again'),
            ),
          ] else if (adventures.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (sections.hero != null) ...[
            HeroAdventureCard(adventure: sections.hero!),
            const SizedBox(height: 24),
            const NeedsYou(),
            OutlinedButton.icon(
              onPressed: () => context.push(newAdventureRoute),
              icon: const Icon(Icons.add),
              label: const Text('New adventure'),
            ),
            RecentActivity(
              trips: [
                sections.hero!,
                ...sections.alsoNow,
                ...sections.upcoming,
              ],
            ),
            if (sections.alsoNow.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Also happening now', style: text.headlineSmall),
              const SizedBox(height: 8),
              for (final a in sections.alsoNow)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OtherTripCard(adventure: a),
                ),
            ],
            if (sections.upcoming.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Upcoming adventures', style: text.headlineSmall),
              const SizedBox(height: 8),
              for (final a in sections.upcoming) UpcomingTrip(adventure: a),
            ],
          ] else ...[
            const InvitesList(),
            const PlanAdventureCard(),
            const SizedBox(height: 24),
            const NeedsYou(withInvites: false),
            if (sections.past.isEmpty) const NoAdventuresCard(),
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
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => showEnterInviteCode(context, ref),
            child: const Text('Have an invite code?'),
          ),
        ],
      ),
    );
  }
}
