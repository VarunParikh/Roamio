import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/banners/data/banner_service.dart';
import 'package:roamio/features/sync/sync_controller.dart';

/// Loads [image] into the phone's cache. Throws if it can't be loaded:
/// Flutter's own [precacheImage] never fails, it only logs an app error.
Future<void> saveImage(ImageProvider image, BuildContext context) async {
  Object? failure;
  await precacheImage(image, context, onError: (error, _) => failure = error);
  if (failure case final error?) throw Exception('Couldn’t load it: $error');
}

/// Saves a banner on the phone, in the cache the adventure banner reads from.
/// Throws when the photo can't be fetched, so it's tried again (see
/// [BannerPreloader]).
final saveBannerProvider =
    Provider<Future<void> Function(BuildContext, String url)>(
      (ref) =>
          (context, url) => saveImage(CachedNetworkImageProvider(url), context),
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
  /// How long a banner that failed to save waits before it's tried again.
  static const retryAfter = Duration(minutes: 5);

  final _saved = <String>{};

  /// A retry timer per banner, so one failing banner can't cancel another's.
  final _retries = <String, Timer>{};

  @override
  void dispose() {
    for (final t in _retries.values) {
      t.cancel();
    }
    super.dispose();
  }

  /// A banner that doesn't save is forgotten after [retryAfter], so the next
  /// build tries it again (item 15). Saved ones are never retried.
  void _save(BuildContext context, String url) {
    unawaited(
      ref.read(saveBannerProvider)(context, url).catchError((_) {
        _retries[url]?.cancel();
        _retries[url] = Timer(retryAfter, () {
          if (!mounted) return;
          _saved.remove(url);
          setState(() {});
        });
      }),
    );
  }

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
        if (mounted) _save(context, url);
      });
    }
    return const SizedBox.shrink();
  }
}
