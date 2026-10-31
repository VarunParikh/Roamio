import 'dart:async';

import 'package:roamio/features/tabs/data/tab_service.dart';

/// Several queries' tabs as one list, newest first, each tab once. Separate
/// queries because the security rules hide some tabs from some people, and a
/// query must only ask for what it's allowed to see (spec UC-21a). Emits once
/// all have answered; an error from any is passed on.
Stream<List<TabEntry>> mergedTabs(List<Stream<List<TabEntry>>> sources) {
  late final StreamController<List<TabEntry>> out;
  final subscriptions = <StreamSubscription<List<TabEntry>>>[];
  final latest = List<List<TabEntry>?>.filled(sources.length, null);

  void emit() {
    if (latest.contains(null)) return;
    final byId = {
      for (final tabs in latest)
        for (final t in tabs!) t.id: t,
    };
    out.add(byId.values.toList()..sort((a, b) => b.date.compareTo(a.date)));
  }

  out = StreamController<List<TabEntry>>(
    onListen: () {
      for (final (i, source) in sources.indexed) {
        subscriptions.add(
          source.listen((tabs) {
            latest[i] = tabs;
            emit();
          }, onError: out.addError),
        );
      }
    },
    onCancel: () async {
      await Future.wait(subscriptions.map((s) => s.cancel()));
    },
  );
  return out.stream;
}
