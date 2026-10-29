import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/privacy/privacy_policy.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/notifications/data/notification_service.dart';
import 'package:roamio/features/profile/data/profile_service.dart';

/// One switch per purpose (spec §8): notifications, location and camera.
/// Shown on the You page and in the Privacy centre.
class ConsentSwitches extends ConsumerWidget {
  const new({super.key});

  Future<void> _setNotifications(
    BuildContext context,
    WidgetRef ref, {
    required bool on,
  }) async {
    final service = ref.read(notificationServiceProvider);
    if (!on) {
      await service.decline();
      return;
    }
    final granted = await service.turnOn();
    if (!granted && context.mounted) {
      showAuthMessage(
        context,
        'Notifications are off. You can allow them in settings later.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationConsentProvider).value == true;
    final allowsLocation = ref.watch(privacyPolicyProvider).allowsLocation;
    final location =
        allowsLocation && (ref.watch(locationAllowedProvider).value ?? false);
    final camera = ref.watch(cameraAllowedProvider).value ?? true;
    final profile = ref.read(profileServiceProvider);

    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Notifications'),
          subtitle: const Text(
            'Alerts when friends join and when you near your budget.',
          ),
          value: notifications,
          onChanged: (on) => unawaited(_setNotifications(context, ref, on: on)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Location'),
          subtitle: Text(
            allowsLocation
                ? 'Lets you add where a tab happened. Android still asks '
                      'when you use it.'
                : 'Location is always off for under-18 accounts.',
          ),
          value: location,
          onChanged: allowsLocation
              ? (on) => unawaited(profile.setLocationAllowed(allowed: on))
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Camera'),
          subtitle: const Text(
            'Lets you take photos in the app. Off, you can still choose '
            'them from your gallery.',
          ),
          value: camera,
          onChanged: (on) => unawaited(profile.setCameraAllowed(allowed: on)),
        ),
      ],
    );
  }
}
