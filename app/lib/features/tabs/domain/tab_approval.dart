import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

const waitingLabel = 'Waiting for approval';
const rejectedLabel = 'Rejected';
const personalLabel = 'Personal: only you can see it';
const alreadyDecidedMessage = 'Another admin has already decided this tab.';

/// [uid] paid and only they share: a personal tab, which needs no approval
/// and only they can see (spec UC-21a).
bool isPersonalShape(String uid, List<Payment> payers, List<String> sharing) =>
    payers.length == 1 &&
    payers.single.payer == uid &&
    sharing.length == 1 &&
    sharing.single == uid;

/// How a tab [uid] adds starts: personal, or waiting for an admin unless
/// they're the only admin, with nobody else to approve it (spec UC-21a).
TabStatus statusForNewTab(
  Adventure adventure,
  String uid,
  List<Payment> payers,
  List<String> sharing,
) => isPersonalShape(uid, payers, sharing)
    ? TabStatus.personal
    : adventure.isOnlyAdmin(uid)
    ? TabStatus.approved
    : TabStatus.waiting;

/// Whether what people owe changed. How someone paid doesn't count, so
/// changing that doesn't need approving again (spec UC-21a).
bool moneyChanged(
  TabEntry old, {
  required int amountMinor,
  required String currency,
  required List<Payment> payers,
  required List<String> sharing,
  required Map<String, int>? percentBp,
}) {
  final was = old.split;
  bool sameList<T>(List<T> a, List<T> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);
  final wasBp = was.percentBp;
  final sameBp = wasBp == null || percentBp == null
      ? wasBp == null && percentBp == null
      : wasBp.length == percentBp.length &&
            wasBp.entries.every((e) => percentBp[e.key] == e.value);
  return was.amount.minor != amountMinor ||
      was.amount.currency != currency ||
      !sameList(
        [for (final p in was.payers) '${p.payer}:${p.amountMinor}'],
        [for (final p in payers) '${p.payer}:${p.amountMinor}'],
      ) ||
      !sameList(was.participants, sharing) ||
      !sameBp;
}

/// The status after [uid] edits [old] (spec UC-21a): left with only them it's
/// personal; a personal or rejected tab starts like a new one; and a money
/// edit to an approved tab needs approving again.
TabStatus statusForEditedTab(
  Adventure adventure,
  String uid,
  TabEntry old, {
  required int amountMinor,
  required String currency,
  required List<Payment> payers,
  required List<String> sharing,
  required Map<String, int>? percentBp,
}) {
  if (isPersonalShape(uid, payers, sharing)) return TabStatus.personal;
  return switch (old.status) {
    TabStatus.personal ||
    TabStatus.rejected => statusForNewTab(adventure, uid, payers, sharing),
    TabStatus.approved
        when !adventure.isOnlyAdmin(uid) &&
            moneyChanged(
              old,
              amountMinor: amountMinor,
              currency: currency,
              payers: payers,
              sharing: sharing,
              percentBp: percentBp,
            ) =>
      TabStatus.waiting,
    final same => same,
  };
}

/// Whether [uid] can approve or reject [tab] (spec UC-21a). The security rules
/// say the same; this only decides which buttons show.
bool canDecideTab(Adventure adventure, TabEntry tab, String uid) =>
    tab.status == TabStatus.waiting &&
    adventure.isLead(uid) &&
    (tab.createdBy != uid || adventure.isOnlyAdmin(uid));

/// The waiting tabs [uid] can approve or reject: what the expanded card counts
/// as waiting for them, so it matches Needs you (spec UC-21a).
List<TabEntry> tabsYouCanDecide(
  Adventure adventure,
  List<TabEntry> tabs,
  String uid,
) => [
  for (final t in tabs)
    if (canDecideTab(adventure, t, uid)) t,
];

/// Who can delete a tab: admins, or its creator for a personal one, which
/// admins can't see, or a rejected one (spec UC-21a, UC-22).
bool canDeleteTab(Adventure adventure, TabEntry tab, String uid) =>
    switch (tab.status) {
      TabStatus.personal => tab.createdBy == uid,
      TabStatus.rejected => tab.createdBy == uid || adventure.isLead(uid),
      _ => adventure.isLead(uid),
    };
