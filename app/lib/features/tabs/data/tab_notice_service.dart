import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TabNoticeKind {
  waiting,
  rejected,

  /// The server took the person's tab off: it broke a rule the app checks too,
  /// so this only happens to an out-of-date app or a queued tab (item 2).
  removed,
}

/// A tab waiting for this admin, or this person's tab that was rejected
/// (spec UC-21a). The server clears them when the tab stops being either.
class TabNotice {
  const new({
    required this.id,
    required this.kind,
    required this.adventureId,
    required this.tabId,
    this.description = '',
  });

  final String id;
  final TabNoticeKind kind;
  final String adventureId;
  final String tabId;
  final String description;
}

abstract interface class TabNoticeService {
  /// The signed-in person's open notices.
  Stream<List<TabNotice>> notices();

  Future<void> dismiss(String noticeId);
}

/// Overridden in tests; Firestore otherwise.
final tabNoticeServiceProvider = Provider<TabNoticeService>(
  (ref) => FirebaseTabNoticeService(
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
  ),
);

final tabNoticesProvider = StreamProvider<List<TabNotice>>(
  (ref) => ref.watch(tabNoticeServiceProvider).notices(),
);

class FirebaseTabNoticeService implements TabNoticeService {
  new(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('users/${_auth.currentUser!.uid}/notifications');

  @override
  Stream<List<TabNotice>> notices() => _notifications
      .where('type', whereIn: ['tab_waiting', 'tab_rejected', 'tab_removed'])
      .snapshots()
      .map(
        (q) => [
          for (final d in q.docs)
            TabNotice(
              id: d.id,
              kind: switch (d['type']) {
                'tab_waiting' => TabNoticeKind.waiting,
                'tab_removed' => TabNoticeKind.removed,
                _ => TabNoticeKind.rejected,
              },
              adventureId: d['adventureId'] as String,
              tabId: d['tabId'] as String,
              description: d.data()['description'] as String? ?? '',
            ),
        ],
      );

  @override
  Future<void> dismiss(String noticeId) =>
      _notifications.doc(noticeId).delete();
}
