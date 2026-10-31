import 'dart:async';

import 'package:flutter/foundation.dart';

/// Changes made offline that the server refused when they were sent. They
/// are gone from the server, so the person has to make them again; Sync
/// reports them rather than saying "Synced ✓" (item 2).
class RefusedWrites {
  final _refused = ValueNotifier<List<String>>(const []);

  /// What wasn't saved, e.g. "a tab", in the order refused.
  ValueListenable<List<String>> get refused => _refused;

  void add(String what) => _refused.value = [..._refused.value, what];

  /// What is waiting to be reported, without taking it.
  List<String> get pending => _refused.value;

  /// Takes the list, once Sync has reported it.
  List<String> take() {
    final all = _refused.value;
    _refused.value = const [];
    return all;
  }

  void clear() => _refused.value = const [];
}

/// The refusals of this run of the app.
final refusedWrites = RefusedWrites();

/// Keeps a write that goes out while offline: it returns at once and the
/// write is queued. If the server later refuses it, [what] is recorded so the
/// person is told it wasn't saved.
void keepWrite(Future<void> write, String what) {
  unawaited(write.catchError((Object _) => refusedWrites.add(what)));
}

extension KeepWrite on Future<void> {
  /// Like [keepWrite], for the end of a write chain.
  void keepOrReport(String what) => keepWrite(this, what);
}
