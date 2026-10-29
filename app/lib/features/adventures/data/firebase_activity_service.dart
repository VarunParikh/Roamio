import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roamio/features/adventures/data/activity_service.dart';

class FirebaseActivityService implements ActivityService {
  new(this._db);

  final FirebaseFirestore _db;

  static const _tabTypes = {'tab_deleted', 'tab_edit_replaced', 'tab_rejected'};

  @override
  Stream<List<ActivityEntry>> recent(String adventureId) => _db
      .collection('adventures/$adventureId/activity')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .asyncMap((q) async {
        // Deleted and rejected tabs aren't in the tab list, so read their
        // names here (members may read every tab, deleted or not).
        final tabIds = {
          for (final d in q.docs)
            if (_tabTypes.contains(d['type'])) d['subject'] as String,
        };
        final tabs = await Future.wait(
          tabIds.map(
            (id) => _db
                .doc('adventures/$adventureId/tabs/$id')
                .get()
                .then((s) => MapEntry(id, s.data()?['description'] as String?))
                .catchError((Object _) => MapEntry<String, String?>(id, null)),
          ),
        );
        final names = Map.fromEntries(tabs);
        return [
          for (final d in q.docs)
            ActivityEntry(
              id: d.id,
              type: d['type'] as String,
              actorUid: (d.data()['actorUid'] as String?) ?? '',
              subject: (d.data()['subject'] as String?) ?? '',
              createdAt: (d.data()['createdAt'] as Timestamp?)?.toDate(),
              tabDescription: names[d.data()['subject']],
              reason: d.data()['reason'] as String?,
            ),
        ];
      });
}
