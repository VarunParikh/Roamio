import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// One line of an adventure's activity, as the server logged it.
class ActivityEntry {
  const new({
    required this.id,
    required this.type,
    required this.actorUid,
    required this.subject,
    required this.createdAt,
    this.tabDescription,
    this.reason,
  });

  final String id;
  final String type;
  final String actorUid;

  /// A member's uid, a tab id or a payment id, depending on [type].
  final String subject;
  final DateTime? createdAt;

  /// The tab's description, for tab entries whose tab can still be read.
  final String? tabDescription;

  /// Why a tab was rejected (`tab_rejected`).
  final String? reason;
}

/// An adventure's activity log (server-written; members read it).
abstract interface class ActivityService {
  /// The latest entries, newest first.
  Stream<List<ActivityEntry>> recent(String adventureId);
}

final activityServiceProvider = Provider<ActivityService>(
  (ref) =>
      throw UnimplementedError('activityServiceProvider must be overridden'),
);

final StreamProviderFamily<List<ActivityEntry>, String> activityProvider =
    StreamProvider.family<List<ActivityEntry>, String>(
      (ref, adventureId) =>
          ref.watch(activityServiceProvider).recent(adventureId),
    );

/// The sentence for [e], or null for a type this version doesn't know.
/// [who] names a uid (members, people who left, "Deleted user").
String? describeActivity(
  ActivityEntry e, {
  required String myUid,
  required String Function(String uid) who,
}) {
  String name(String uid) => uid == myUid ? 'You' : who(uid);
  final actor = name(e.actorUid);
  final tab = e.tabDescription == null ? 'a tab' : '“${e.tabDescription}”';
  return switch (e.type) {
    'member_joined' => '${name(e.subject)} joined the squad',
    'member_left' => '${name(e.subject)} left the squad',
    'member_removed' => '$actor removed ${name(e.subject)}',
    'co_lead_added' => '$actor made ${name(e.subject)} a co-lead',
    'co_lead_removed' => '$actor made ${name(e.subject)} a member again',
    'leader_changed' => '$actor handed squad leadership to ${name(e.subject)}',
    'tab_deleted' => '$actor deleted $tab',
    'tab_declined' => '$actor rejected $tab',
    'tab_edit_replaced' =>
      '${e.actorUid == myUid ? 'Your' : '$actor’s'} offline edit replaced '
          'a newer change to $tab',
    'tab_rejected' =>
      '${tab[0].toUpperCase()}${tab.substring(1)} was removed'
          '${e.reason == null ? '' : ': ${e.reason}'}',
    'settlement_recorded' => '$actor recorded a payment',
    'settlement_undone' => '$actor undid a payment',
    _ => null,
  };
}
