import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/sync/sync_controller.dart';

/// Why a button is switched off while offline (UC-33).
const needsConnectionNote = 'Needs a connection. Available once you’re back.';

/// The reason under a button that is switched off while offline.
class NeedsConnectionNote extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      needsConnectionNote,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: RoamioColors.slate),
    ),
  );
}

/// The offline notice and Sync button on Home and the adventure page.
/// Nothing shows while online.
class SyncBanner extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SyncBanner> createState() => _SyncBannerState();
}

class _SyncBannerState extends ConsumerState<SyncBanner> {
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _sync() => unawaited(ref.read(syncControllerProvider.notifier).sync());

  @override
  Widget build(BuildContext context) {
    ref.listen(syncControllerProvider, (_, next) {
      _hide?.cancel();
      if (next.phase == SyncPhase.synced) {
        _hide = Timer(
          const Duration(seconds: 3),
          ref.read(syncControllerProvider.notifier).dismissSynced,
        );
      }
    });
    final state = ref.watch(syncControllerProvider);
    final text = Theme.of(context).textTheme;

    final (icon, message, action) = switch (state.phase) {
      SyncPhase.online => (null, null, null),
      SyncPhase.offline => (
        Icons.cloud_off_rounded,
        'You’re offline. Your changes are saved on this phone and sync by '
            'themselves when you’re back.',
        null,
      ),
      SyncPhase.syncing => (Icons.sync_rounded, 'Syncing…', null),
      SyncPhase.synced => (Icons.cloud_done_rounded, 'Synced ✓', null),
      SyncPhase.failed => (
        Icons.sync_problem_rounded,
        'Couldn’t sync: ${state.error}',
        'Try again',
      ),
    };
    if (message == null) return const SizedBox.shrink();

    return Semantics(
      liveRegion: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (state.phase == SyncPhase.syncing)
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, color: RoamioColors.slate),
              const SizedBox(width: 12),
              Expanded(child: Text(message, style: text.bodyMedium)),
              if (action != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(88, 48),
                  ),
                  onPressed: _sync,
                  child: Text(action),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
