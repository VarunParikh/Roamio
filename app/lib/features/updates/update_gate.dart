import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/config/remote_config.dart';
import 'package:roamio/features/banners/data/banner_service.dart';
import 'package:roamio/features/updates/update_checker.dart';

/// Checks for an update once when the main tabs open and shows the popup
/// (UC-34): dismissible with Later, or blocking below
/// `min_supported_version`.
class UpdateGate extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    // The minimum version comes from Remote Config; defaults if unreachable.
    await ref.read(remoteValuesProvider.future);
    if (!mounted) return;
    final checker = ref.read(updateCheckerProvider);
    final notice = await checker.check(
      current: appVersion,
      minSupported: ref.read(appConfigProvider).minSupportedVersion,
    );
    if (notice == null || !mounted) return;
    final later = await showDialog<bool>(
      context: context,
      barrierDismissible: !notice.blocking,
      builder: (_) => _UpdateDialog(notice: notice),
    );
    if (later ?? false) await checker.dismiss(notice);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _UpdateDialog extends ConsumerWidget {
  const new({required this.notice});

  final UpdateNotice notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopScope(
    canPop: !notice.blocking,
    child: AlertDialog(
      title: Text(notice.blocking ? 'Update needed' : 'Update available'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              notice.blocking
                  ? 'This version of Roamio is no longer supported. Install '
                        'version ${notice.version} or later to keep going.'
                  : 'Roamio ${notice.version} is ready.',
            ),
            if (notice.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(notice.notes.trim()),
            ],
            const SizedBox(height: 12),
            const Text(
              'Download update opens the release page. Tap the .apk file '
              'under Assets, then open it to install.',
            ),
          ],
        ),
      ),
      actions: [
        if (!notice.blocking)
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Later'),
          ),
        FilledButton(
          onPressed: () => ref.read(openLinkProvider)(notice.downloadUrl),
          child: const Text('Download update'),
        ),
      ],
    ),
  );
}
