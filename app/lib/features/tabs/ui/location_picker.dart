import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/core/privacy/privacy_policy.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/profile/data/profile_service.dart';

/// "Add location" for a tab (spec UC-21). Shown only to adults (§7.2) who
/// have switched Location on in You (§8); reads the location once, when
/// tapped, after Android's permission prompt.
class LocationPicker extends ConsumerStatefulWidget {
  const new({required this.point, required this.onChanged, super.key});

  final MapPoint? point;
  final ValueChanged<MapPoint?> onChanged;

  @override
  ConsumerState<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends ConsumerState<LocationPicker> {
  bool _busy = false;

  Future<void> _locate() async {
    setState(() => _busy = true);
    final service = ref.read(locationServiceProvider);
    final result = await service.current();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Located(:final point):
        widget.onChanged(point);
      case LocationServicesOff():
        await _offerSettings(
          title: 'Turn on location services',
          body:
              'Your phone’s location is switched off. Turn it on, then tap '
              'Add location again.',
          open: service.openLocationSettings,
        );
      case LocationDenied(forever: true):
        await _offerSettings(
          title: 'Allow location',
          body:
              'Location is off for Roamio. Allow it in settings to tag where '
              'tabs happen.',
          open: service.openAppSettings,
        );
      case LocationDenied(forever: false):
        showAuthMessage(context, 'Location wasn’t allowed, so none was added.');
      case LocationFailed():
        showAuthMessage(context, 'Couldn’t find your location. Try again.');
    }
  }

  Future<void> _offerSettings({
    required String title,
    required String body,
    required Future<void> Function() open,
  }) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (go ?? false) await open();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(privacyPolicyProvider).allowsLocation) {
      return const SizedBox.shrink();
    }
    final allowed = ref.watch(locationAllowedProvider).value ?? false;
    if (widget.point != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              '📍 ${widget.point!.label}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          IconButton(
            tooltip: 'Remove location',
            icon: const Icon(Icons.close),
            onPressed: () => widget.onChanged(null),
          ),
        ],
      );
    }
    return OutlinedButton.icon(
      // Choosing to add one is what turns the setting on (spec UC-21).
      onPressed: _busy
          ? null
          : () {
              if (!allowed) {
                unawaited(
                  ref
                      .read(profileServiceProvider)
                      .setLocationAllowed(allowed: true),
                );
              }
              unawaited(_locate());
            },
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.place_outlined),
      label: const Text('Add location'),
    );
  }
}
