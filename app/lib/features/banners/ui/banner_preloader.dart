import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/banners/data/banner_service.dart';
import 'package:roamio/features/sync/sync_controller.dart';

/// Saves a banner on the phone, in the cache the adventure banner reads from.
/// A photo that can't be fetched stays quiet: the card keeps its fallback.
final saveBannerProvider =
    Provider<Future<void> Function(BuildContext, String url)>(
      (ref) =>
          (context, url) => precacheImage(
            CachedNetworkImageProvider(url),
            context,
            onError: (_, _) {},
          ),
    );

/// Saves the banner of every current and upcoming trip while there's a
/// connection, so they still show while travelling (spec §9.2). The photos
/// stay Unsplash's: this is the phone's own cache of their links. Shows
/// nothing.
class BannerPreloader extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<BannerPreloader> createState() => _BannerPreloaderState();
}

class _BannerPreloaderState extends ConsumerState<BannerPreloader> {
  final _saved = <String>{};

  @override
  Widget build(BuildContext context) {
    if (ref.watch(isOfflineProvider)) return const SizedBox.shrink();
    final today = ref.watch(todayProvider);
    final ahead =
        ref
            .watch(myAdventuresProvider)
            .value
            ?.where((a) => a.statusOn(today) != AdventureStatus.past) ??
        const <Adventure>[];
    for (final a in ahead) {
      final url =
          a.bannerUrl ?? ref.watch(bannerProvider(a.countryCode)).value?.url;
      if (url == null || !_saved.add(url)) continue;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(ref.read(saveBannerProvider)(context, url));
      });
    }
    return const SizedBox.shrink();
  }
}
