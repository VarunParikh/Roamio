import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

const waitingLabel = 'Waiting for approval';
const alreadyDecidedMessage = 'Another admin has already decided this tab.';

/// How a tab [uid] adds starts: waiting for an admin, unless they're the only
/// admin, with nobody else to approve it (spec UC-21a).
TabStatus statusForNewTab(Adventure adventure, String uid) =>
    adventure.isOnlyAdmin(uid) ? TabStatus.approved : TabStatus.waiting;

/// Whether [uid] can approve or reject [tab] (spec UC-21a). The security rules
/// say the same; this only decides which buttons show.
bool canDecideTab(Adventure adventure, TabEntry tab, String uid) =>
    tab.status == TabStatus.waiting &&
    adventure.isLead(uid) &&
    (tab.createdBy != uid || adventure.isOnlyAdmin(uid));
