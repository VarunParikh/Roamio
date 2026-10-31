import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/config/phase2.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/images/photo_pipeline.dart';
import 'package:roamio/core/images/upload_queue.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/auth/ui/dob_field.dart';
import 'package:roamio/features/consent/data/consent_service.dart';
import 'package:roamio/features/profile/data/profile_service.dart';
import 'package:roamio/features/profile/domain/characters.dart';
import 'package:roamio/features/profile/ui/character_avatar.dart';
import 'package:roamio/features/profile/ui/character_picker.dart';
import 'package:roamio/features/profile/ui/consent_switches.dart';
import 'package:roamio/features/profile/ui/privacy_centre.dart';

final StreamProvider<List<LinkedChild>> _linkedChildrenProvider =
    StreamProvider.autoDispose<List<LinkedChild>>(
      (ref) => ref.watch(consentServiceProvider).linkedChildren(),
    );

/// The You tab (spec UC-28): photo, name, description, profile currency,
/// notification and location switches, then Linked children (spec §7.3)
/// the Privacy centre link and signing out.
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

  Future<void> _chooseCharacter(String? current) async {
    final id = await showCharacterPicker(context, current: current);
    if (id != null) await ref.read(profileServiceProvider).setCharacter(id);
  }

  Future<void> _changePhoto() async {
    final cameraAllowed = ref.read(cameraAllowedProvider).value ?? true;
    final camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cameraAllowed)
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
      // A character would hide the new photo.
      await ref.read(profileServiceProvider).setCharacter(null);
      if (mounted) {
        showAuthMessage(context, 'Your photo will appear once it’s uploaded.');
      }
    } on FormatException {
      if (mounted) {
        showAuthMessage(context, 'That photo couldn’t be read. Try another.');
      }
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
    // Linked children are a Phase 2 feature (lib/core/config/phase2.dart).
    final children = ref.watch(minorsEnabledProvider)
        ? ref.watch(_linkedChildrenProvider).value ?? const <LinkedChild>[]
        : const <LinkedChild>[];
    final currency = ref.watch(profileCurrencyProvider).value ?? 'INR';
    final currencies = {
      ...?ref.watch(countriesProvider).value?.currencies,
      currency,
    }.toList()..sort();
    final uploads = ref.watch(photoUploadsEnabledProvider);
    final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';

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
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: CharacterAvatar(
                    uid: myUid,
                    characterId: profile?.characterId,
                    photoUrl: uploads ? profile?.photoUrl : null,
                    radius: 48,
                    loading: profile == null,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filledTonal(
                    tooltip: 'Choose your character',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _chooseCharacter(
                      characterFor(myUid, profile?.characterId).id,
                    ),
                  ),
                ),
                if (uploads)
                  Positioned(
                    left: 0,
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
          const ConsentSwitches(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Privacy centre'),
            subtitle: const Text(
              'Download or delete your data, and how to reach us.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(privacyCentreRoute),
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
