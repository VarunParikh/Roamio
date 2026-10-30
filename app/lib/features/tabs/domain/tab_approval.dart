import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

const waitingLabel = 'Waiting for approval';
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

/// The status after [uid] edits a tab: left with only them it's personal, and
/// a personal tab they add someone to starts like a new one (spec UC-21a).
TabStatus statusForEditedTab(
  Adventure adventure,
  String uid,
  TabStatus before,
  List<Payment> payers,
  List<String> sharing,
) => isPersonalShape(uid, payers, sharing)
    ? TabStatus.personal
    : before == TabStatus.personal
    ? statusForNewTab(adventure, uid, payers, sharing)
    : before;

/// Whether [uid] can approve or reject [tab] (spec UC-21a). The security rules
/// say the same; this only decides which buttons show.
bool canDecideTab(Adventure adventure, TabEntry tab, String uid) =>
    tab.status == TabStatus.waiting &&
    adventure.isLead(uid) &&
    (tab.createdBy != uid || adventure.isOnlyAdmin(uid));

/// Who can delete a tab: admins, or for a personal one its creator, since
/// admins can't see it (spec UC-21a, UC-22).
bool canDeleteTab(Adventure adventure, TabEntry tab, String uid) =>
    tab.status == TabStatus.personal
    ? tab.createdBy == uid
    : adventure.isLead(uid);
