import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/data/activity_service.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/dob_field.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/squad/ui/person.dart';
import 'package:roamio/features/tabs/ui/tabs_section.dart';

/// What has happened in an adventure, newest first: joins, role changes,
/// deleted or rejected tabs, offline edits that replaced newer ones
/// (UC-32) and payments recorded or undone (UC-26a).
class ActivityScreen extends ConsumerWidget {
  const new({required this.adventureId, super.key});

  final String adventureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adventure = ref
        .watch(myAdventuresProvider)
        .value
        ?.where((a) => a.id == adventureId)
        .firstOrNull;
    final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';
    final activity = ref.watch(activityProvider(adventureId));
    final entries = activity.value;
    final people = adventure == null
        ? const <String, SquadPerson>{}
        : squadPeople(ref, adventure);
    final lines = [
      for (final e in entries ?? const <ActivityEntry>[])
        if (describeActivity(
              e,
              myUid: myUid,
              who: (id) => people[id]?.name ?? deletedUserName,
            )
            case final line?)
          (line, e.createdAt, e.actorUid),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: activity.hasError && entries == null
          ? _Next(
              text: 'We couldn’t load the activity.',
              action: OutlinedButton(
                onPressed: () => ref.invalidate(activityProvider(adventureId)),
                child: const Text('Try again'),
              ),
            )
          : entries == null
          ? const Center(child: CircularProgressIndicator())
          : lines.isEmpty
          ? _Next(
              text: 'Nothing has happened yet.',
              action: OutlinedButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/adventures/$adventureId'),
                child: const Text('Back to the adventure'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: lines.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final (line, at, actor) = lines[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: PersonAvatar(uid: actor, person: people[actor]),
                  title: Text(line),
                  subtitle: at == null ? null : Text(formatDate(at)),
                );
              },
            ),
    );
  }
}

/// An empty or error state with its one next action (spec §12).
class _Next extends StatelessWidget {
  const new({required this.text, required this.action});

  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: RoamioColors.slate),
        ),
        const SizedBox(height: 16),
        action,
      ],
    ),
  );
}
