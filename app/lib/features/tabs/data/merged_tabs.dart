import 'dart:async';

import 'package:roamio/features/tabs/data/tab_service.dart';

/// Shared tabs and your own personal ones as one list, newest first. Two
/// queries, because the security rules hide other people's personal tabs and
/// a query must only ask for what it's allowed to see (spec UC-21a). Emits
/// once both have answered; an error from either is passed on.
Stream<List<TabEntry>> mergedTabs(
  Stream<List<TabEntry>> shared,
  Stream<List<TabEntry>> personal,
) {
  late final StreamController<List<TabEntry>> out;
  final subscriptions = <StreamSubscription<List<TabEntry>>>[];
  List<TabEntry>? latestShared;
  List<TabEntry>? latestPersonal;

  void emit() {
    final a = latestShared;
    final b = latestPersonal;
    if (a == null || b == null) return;
    out.add([...a, ...b]..sort((x, y) => y.date.compareTo(x.date)));
  }

  out = StreamController<List<TabEntry>>(
    onListen: () {
      subscriptions
        ..add(
          shared.listen((tabs) {
            latestShared = tabs;
            emit();
          }, onError: out.addError),
        )
        ..add(
          personal.listen((tabs) {
            latestPersonal = tabs;
            emit();
          }, onError: out.addError),
        );
    },
    onCancel: () async {
      await Future.wait(subscriptions.map((s) => s.cancel()));
    },
  );
  return out.stream;
}
