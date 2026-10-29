import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/images/photo_pipeline.dart';
import 'package:roamio/core/images/upload_queue.dart';
import 'package:roamio/core/privacy/privacy_policy.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/auth/ui/dob_field.dart';
import 'package:roamio/features/consent/data/consent_service.dart';
import 'package:roamio/features/notifications/data/notification_service.dart';
import 'package:roamio/features/profile/data/profile_service.dart';

final StreamProvider<List<LinkedChild>> _linkedChildrenProvider =
    StreamProvider.autoDispose<List<LinkedChild>>(
      (ref) => ref.watch(consentServiceProvider).linkedChildren(),
    );

/// The You tab (spec UC-28): photo, name, description, profile currency,
/// notification and location switches, then Linked children (spec §7.3)
/// and signing out. The privacy centre arrives in Task 35.
class YouScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends ConsumerState<YouScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  bool _filled = false;
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Add your name so your squad knows you.');
      return;
    }
    setState(() => _nameError = null);
    unawaited(
      ref
          .read(profileServiceProvider)
          .saveProfile(name: name, bio: _bio.text.trim()),
    );
    showAuthMessage(context, 'Profile saved.');
  }

  Future<void> _changePhoto() async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
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
    if (camera == null || !mounted) return;
    final photos = ref.read(photoPipelineProvider);
    final path = await photos.pick(camera: camera);
    if (path == null) return;
    final uid = ref.read(sessionFactsProvider).value?.uid ?? '';
    try {
      await photos.queueUpload(
        path: path,
        kind: PhotoKind.photo,
        storageDir: 'users/$uid/avatar',
        docPath: 'users/$uid',
        field: 'photoUrl',
        mode: UploadMode.replace,
      );
      if (mounted) {
        showAuthMessage(context, 'Your photo will appear once it’s uploaded.');
      }
    } on FormatException {
      if (mounted) {
        showAuthMessage(context, 'That photo couldn’t be read. Try another.');
      }
    }
  }

  Future<void> _setNotifications({required bool on}) async {
    final service = ref.read(notificationServiceProvider);
    if (!on) {
      await service.decline();
      return;
    }
    final granted = await service.turnOn();
    if (!granted && mounted) {
      showAuthMessage(
        context,
        'Notifications are off. You can allow them in settings later.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final profile = ref.watch(profileStreamProvider).value;
    if (profile != null && !_filled) {
      _filled = true;
      _name.text = profile.name;
      _bio.text = profile.bio;
    }
    final children = ref.watch(_linkedChildrenProvider).value ?? const [];
    final currency = ref.watch(profileCurrencyProvider).value ?? 'INR';
    final currencies = {
      ...?ref.watch(countriesProvider).value?.currencies,
      currency,
    }.toList()..sort();
    final notifications = ref.watch(notificationConsentProvider).value == true;
    final allowsLocation = ref.watch(privacyPolicyProvider).allowsLocation;
    final location =
        allowsLocation && (ref.watch(locationAllowedProvider).value ?? false);
    final photoUrl = profile?.photoUrl;
    final initial = _name.text.trim().characters.firstOrNull ?? '?';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          Text('You', style: text.displayLarge),
          const SizedBox(height: 24),
          Text('Your profile', style: text.headlineSmall),
          const SizedBox(height: 12),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: RoamioColors.hairline,
                  foregroundColor: RoamioColors.ink,
                  backgroundImage: photoUrl == null
                      ? null
                      : CachedNetworkImageProvider(photoUrl),
                  child: photoUrl == null
                      ? Text(initial, style: text.displayMedium)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filledTonal(
                    tooltip: 'Change photo',
                    icon: const Icon(Icons.photo_camera_outlined),
                    onPressed: _changePhoto,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            decoration: InputDecoration(
              labelText: 'Name',
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            maxLines: 3,
            minLines: 1,
            inputFormatters: [LengthLimitingTextInputFormatter(200)],
            decoration: const InputDecoration(labelText: 'About you'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: currency,
            decoration: const InputDecoration(
              labelText: 'Profile currency',
              helperText: 'Amounts on Split and Home appear in this currency.',
              helperMaxLines: 2,
            ),
            items: [
              for (final c in currencies)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (c) {
              if (c != null && c != currency) {
                unawaited(
                  ref.read(profileServiceProvider).setProfileCurrency(c),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Save profile', onPressed: _save),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Notifications'),
            subtitle: const Text(
              'Alerts when friends join and when you near your budget.',
            ),
            value: notifications,
            onChanged: (on) => unawaited(_setNotifications(on: on)),
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
                ? (on) => unawaited(
                    ref
                        .read(profileServiceProvider)
                        .setLocationAllowed(allowed: on),
                  )
                : null,
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text('Linked children', style: text.headlineSmall),
            const SizedBox(height: 8),
            for (final child in children) _LinkedChildTile(child: child),
          ],
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: ref.read(authServiceProvider).signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _LinkedChildTile extends ConsumerWidget {
  const new({required this.child});

  final LinkedChild child;

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Withdraw consent for ${child.name}?'),
        content: Text(
          '${child.name}’s account is paused right away and deleted, with '
          'their data, within 48 hours. This can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep consent'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (!(sure ?? false)) return;
    try {
      await ref.read(consentServiceProvider).withdraw(child.uid);
      if (context.mounted) {
        showAuthMessage(context, 'Consent withdrawn for ${child.name}.');
      }
    } on ConsentException catch (e) {
      if (context.mounted) showAuthMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final since = child.since;
    return Card(
      child: ListTile(
        title: Text(child.name),
        subtitle: Text(
          since == null
              ? 'Consent given'
              : 'Consent given ${formatDate(since)}',
        ),
        trailing: TextButton(
          onPressed: () => _withdraw(context, ref),
          child: const Text('Withdraw'),
        ),
      ),
    );
  }
}
