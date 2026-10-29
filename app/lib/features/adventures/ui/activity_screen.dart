import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/data/activity_service.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/dob_field.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/tabs/ui/tabs_section.dart';

/// What has happened in an adventure, newest first: joins, role changes,
/// deleted or rejected tabs, offline edits that replaced newer ones
/// (UC-32) and payments recorded or undone (UC-26a).
class ActivityScreen extends ConsumerWidget {
  const new({required this.adventureId, super.key});

  final String adventureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final adventure = ref
        .watch(myAdventuresProvider)
        .value
        ?.where((a) => a.id == adventureId)
        .firstOrNull;
    final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';
    final entries = ref.watch(activityProvider(adventureId)).value;
    final labels = adventure == null
        ? const <String, String>{}
        : squadLabels(ref, adventure);
    final lines = [
      for (final e in entries ?? const <ActivityEntry>[])
        if (describeActivity(
              e,
              myUid: myUid,
              who: (id) => labels[id] ?? deletedUserName,
            )
            case final line?)
          (line, e.createdAt),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : lines.isEmpty
          ? Center(
              child: Text(
                'Nothing has happened yet.',
                style: text.bodyLarge?.copyWith(color: RoamioColors.slate),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: lines.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final (line, at) = lines[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(line),
                  subtitle: at == null ? null : Text(formatDate(at)),
                );
              },
            ),
    );
  }
}
