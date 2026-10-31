import 'dart:async';

import 'package:roamio/features/tabs/data/tab_notice_service.dart';

/// In-memory [TabNoticeService]; [decide] stands in for the server clearing
/// every admin's card once a tab is decided.
class FakeTabNoticeService implements TabNoticeService {
  new([List<TabNotice> initial = const []]) : _notices = [...initial];

  final List<TabNotice> _notices;
  final List<String> dismissed = [];
  final _changes = StreamController<void>.broadcast();

  void decide(String tabId) {
    _notices.removeWhere((n) => n.tabId == tabId);
    _changes.add(null);
  }

  @override
  Stream<List<TabNotice>> notices() async* {
    yield [..._notices];
    yield* _changes.stream.map((_) => [..._notices]);
  }

  @override
  Future<void> dismiss(String noticeId) async {
    dismissed.add(noticeId);
    _notices.removeWhere((n) => n.id == noticeId);
    _changes.add(null);
  }
}
