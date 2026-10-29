import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// A country's default banner photo and its required credit (spec §9.2).
class BannerPhoto {
  const new({
    required this.url,
    required this.photographer,
    required this.photographerUrl,
  });

  final String url;
  final String photographer;
  final String photographerUrl;
}

abstract interface class BannerService {
  /// The cached banner for [countryCode], fetching it once if needed; null
  /// when none is available (the app then shows its fallback).
  Future<BannerPhoto?> bannerFor(String countryCode);
}

/// Overridden in `main.dart` with the Firebase implementation.
final bannerServiceProvider = Provider<BannerService>(
  (ref) => throw UnimplementedError('bannerServiceProvider must be overridden'),
);

/// Kept for the session, so each country is looked up at most once.
final FutureProviderFamily<BannerPhoto?, String> bannerProvider =
    FutureProvider.family<BannerPhoto?, String>(
      (ref, countryCode) =>
          ref.watch(bannerServiceProvider).bannerFor(countryCode),
    );

/// Opens a link outside the app; overridden in tests.
final openLinkProvider = Provider<Future<void> Function(Uri)>(
  (ref) => throw UnimplementedError('openLinkProvider must be overridden'),
);
