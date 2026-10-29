import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/banners/data/banner_service.dart';

/// The banner behind an adventure card: the adventure's own photo, else the
/// country's default photo, else a dark gradient with the flag (spec §9.2).
/// Photos are cached on the device after the first load.
class AdventureBanner extends ConsumerWidget {
  const new({
    required this.countryCode,
    required this.flag,
    this.customUrl,
    super.key,
  });

  final String countryCode;
  final String flag;
  final String? customUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = customUrl == null
        ? ref.watch(bannerProvider(countryCode)).value
        : null;
    final url = customUrl ?? photo?.url;
    final fallback = _Fallback(flag: flag);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url == null)
          fallback
        else
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, _) => fallback,
            errorWidget: (_, _, _) => fallback,
          ),
        // Keeps white text readable on any photo.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x330F1115), Color(0xCC0F1115)],
            ),
          ),
        ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const new({required this.flag});

  final String flag;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [RoamioColors.ink, Color(0xFF1E2A4A)],
      ),
    ),
    child: Align(
      alignment: const Alignment(0.85, -0.7),
      child: Text(flag, style: const TextStyle(fontSize: 72)),
    ),
  );
}

/// Unsplash requires crediting the photographer with a link. Shown only on
/// the country's default photo, never on an adventure's own photo.
class BannerCredit extends ConsumerWidget {
  const new({required this.countryCode, this.customUrl, super.key});

  final String countryCode;
  final String? customUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = customUrl == null
        ? ref.watch(bannerProvider(countryCode)).value
        : null;
    if (photo == null) return const SizedBox.shrink();
    return _credit(context, ref, photo);
  }

  Widget _credit(BuildContext context, WidgetRef ref, BannerPhoto photo) =>
      GestureDetector(
        onTap: () =>
            ref.read(openLinkProvider)(Uri.parse(photo.photographerUrl)),
        child: Text(
          'Photo: ${photo.photographer} · Unsplash',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: RoamioColors.surface.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}
