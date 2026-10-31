import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/config/phase2.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/images/photo_pipeline.dart';
import 'package:roamio/core/images/upload_queue.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/banners/ui/adventure_banner.dart';

/// A lead swaps the country photo for their own, or goes back (spec UC-10).
/// Changes apply straight away; an own photo shows once it has uploaded.
class BannerEditor extends ConsumerWidget {
  const new({required this.adventure, super.key});

  final Adventure adventure;

  Future<void> _useOwnPhoto(BuildContext context, WidgetRef ref) async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (camera == null) return;
    final photos = ref.read(photoPipelineProvider);
    final path = await photos.pick(camera: camera);
    if (path == null) return;
    try {
      await photos.queueUpload(
        path: path,
        kind: PhotoKind.photo,
        storageDir: 'adventures/${adventure.id}/banner',
        docPath: 'adventures/${adventure.id}',
        field: 'bannerUrl',
        mode: UploadMode.replace,
      );
      if (context.mounted) {
        showAuthMessage(context, 'Your photo will appear once it’s uploaded.');
      }
    } on FormatException {
      if (context.mounted) {
        showAuthMessage(context, 'That photo couldn’t be read. Try another.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flag = ref
        .watch(countriesProvider)
        .value
        ?.byCode(adventure.countryCode)
        ?.flag;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 140,
            child: AdventureBanner(
              countryCode: adventure.countryCode,
              flag: flag ?? '🌍',
              customUrl: adventure.bannerUrl,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (adventure.bannerUrl == null) ...[
          if (ref.watch(photoUploadsEnabledProvider))
            OutlinedButton.icon(
              onPressed: () => _useOwnPhoto(context, ref),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Use my own photo'),
            ),
        ] else
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(adventureServiceProvider).resetBanner(adventure.id),
            icon: const Icon(Icons.landscape_outlined),
            label: const Text('Use country photo'),
          ),
      ],
    );
  }
}
