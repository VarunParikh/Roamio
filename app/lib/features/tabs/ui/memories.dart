import 'dart:io';

import 'package:flutter/material.dart';
import 'package:roamio/core/theme/roamio_colors.dart';

/// Most photos one tab can hold (spec UC-21).
const maxMemories = 4;

/// Up to [maxMemories] photos picked for a tab, shown as thumbnails until
/// the tab is saved; the photo pipeline then compresses and uploads them.
class MemoriesPicker extends StatelessWidget {
  const new({
    required this.paths,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  final List<String> paths;

  /// Called with true for the camera, false for the gallery.
  final ValueChanged<bool> onAdd;
  final ValueChanged<int> onRemove;

  Future<void> _choose(BuildContext context) async {
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
    if (camera != null) onAdd(camera);
  }

  @override
  Widget build(BuildContext context) {
    final full = paths.length >= maxMemories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (paths.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, path) in paths.indexed)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(path),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 72,
                          height: 72,
                          color: RoamioColors.hairline,
                          child: const Icon(Icons.image_outlined),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton.filledTonal(
                        tooltip: 'Remove photo',
                        iconSize: 16,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close),
                        onPressed: () => onRemove(i),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: full ? null : () => _choose(context),
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Add photo'),
        ),
        if (full)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Up to $maxMemories photos per tab.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: RoamioColors.slate),
            ),
          ),
      ],
    );
  }
}
