import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A change queued for the server, remembered on the phone. Firestore keeps
/// its own queue across a restart, but the answer to a write only reaches the
/// run that made it, so a later run has to look at the record instead.
@immutable
class QueuedWrite {
  const new({
    required this.uid,
    required this.what,
    required this.path,
    this.mustExist = true,
    this.fields = const {},
  });

  factory fromJson(Map<String, Object?> json) => QueuedWrite(
    uid: json['uid']! as String,
    what: json['what']! as String,
    path: json['path']! as String,
    mustExist: json['mustExist']! as bool,
    fields: (json['fields']! as Map).cast<String, Object?>(),
  );

  /// Whose write it is: another person's stays in Firestore's queue for them.
  final String uid;

  /// What to tell the person if it was refused, e.g. "a tab".
  final String what;

  /// The record it writes to.
  final String path;

  /// False for a write that removes the record.
  final bool mustExist;

  /// The values the record has once the write is saved.
  final Map<String, Object?> fields;

  Map<String, Object?> toJson() => {
    'uid': uid,
    'what': what,
    'path': path,
    'mustExist': mustExist,
    'fields': fields,
  };
}

abstract interface class QueuedWriteStore {
  Future<List<QueuedWrite>> read();
  Future<void> write(List<QueuedWrite> writes);
}

/// [QueuedWriteStore] as a JSON file in the app's support folder. Failing to
/// read or write stays quiet: the worst case is the old silent refusal.
class FileQueuedWriteStore implements QueuedWriteStore {
  new({this._folder = getApplicationSupportDirectory});

  final Future<Directory> Function() _folder;

  Future<File> get _file async =>
      File('${(await _folder()).path}/queued_writes.json');

  @override
  Future<List<QueuedWrite>> read() async {
    try {
      final data = jsonDecode(await (await _file).readAsString()) as List;
      return [
        for (final w in data)
          QueuedWrite.fromJson((w as Map).cast<String, Object?>()),
      ];
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> write(List<QueuedWrite> writes) async {
    try {
      await (await _file).writeAsString(jsonEncode(writes));
    } on Object {
      // See the class comment.
    }
  }
}

/// The values of [fields] that can be saved and compared later: not server
/// timestamps and the like.
Map<String, Object?> comparableFields(Map<String, Object?> fields) => {
  for (final MapEntry(:key, :value) in fields.entries)
    if (_comparable(value)) key: value,
};

bool _comparable(Object? value) => switch (value) {
  null || bool() || num() || String() => true,
  final List<Object?> list => list.every(_comparable),
  final Map<Object?, Object?> map => map.values.every(_comparable),
  _ => false,
};

bool _same(Object? a, Object? b) => switch ((a, b)) {
  (final List<Object?> x, final List<Object?> y) =>
    x.length == y.length &&
        [for (var i = 0; i < x.length; i++) i].every((i) => _same(x[i], y[i])),
  (final Map<Object?, Object?> x, final Map<Object?, Object?> y) =>
    x.length == y.length &&
        x.keys.every((k) => y.containsKey(k) && _same(x[k], y[k])),
  _ => a == b,
};

/// Whether the record, as the server has it ([saved], null if there is none),
/// shows that [write] went through.
bool writeApplied(QueuedWrite write, Map<String, Object?>? saved) {
  if (saved == null) return !write.mustExist;
  if (!write.mustExist) return false;
  return write.fields.entries.every(
    (f) => saved.containsKey(f.key) && _same(f.value, saved[f.key]),
  );
}

/// Changes the server refused. They are gone from the server, so the person
/// has to make them again: the app says so until they've seen it, and never
/// "Synced ✓" meanwhile (item 2).
class RefusedWrites {
  final _refused = ValueNotifier<List<String>>(const []);
  final _queued = <String, _Entry>{};
  QueuedWriteStore? _store;
  String? Function() _uid = () => null;
  int _next = 0;

  /// Told of each refusal as it happens, for the crash log.
  void Function(String what)? onRefused;

  /// What wasn't saved, e.g. "a tab", in the order refused.
  ValueListenable<List<String>> get refused => _refused;

  List<String> get pending => _refused.value;

  void add(String what) {
    _refused.value = [..._refused.value, what];
    onRefused?.call(what);
  }

  void clear() => _refused.value = const [];

  /// Picks up what the last run left on the phone. [uid] says who is signed in.
  Future<void> load(
    QueuedWriteStore store, {
    required String? Function() uid,
  }) async {
    _store = store;
    _uid = uid;
    for (final write in await store.read()) {
      _queued[write.path] = _Entry(write, earlier: true);
    }
  }

  /// Follows [write], which returns only once the server has answered. With a
  /// [path], it's also remembered on the phone until then: [fields] are the
  /// values it sets, for checking after a restart.
  void track(
    Future<void> write,
    String what, {
    String? path,
    Map<String, Object?> fields = const {},
    bool mustExist = true,
  }) {
    final uid = _uid();
    final id = _next++;
    if (path != null && uid != null) {
      _queued[path] = _Entry(
        QueuedWrite(
          uid: uid,
          what: what,
          path: path,
          mustExist: mustExist,
          fields: comparableFields(fields),
        ),
        id: id,
      );
      _save();
    }
    void answered() {
      if (path != null && _queued[path]?.id == id) {
        _queued.remove(path);
        _save();
      }
    }

    unawaited(
      write.then(
        (_) => answered(),
        onError: (Object _) {
          answered();
          add(what);
        },
      ),
    );
  }

  /// Whether an earlier run left writes to look at.
  bool get hasEarlier => _queued.values.any((e) => e.earlier);

  /// Looks at what an earlier run left: [check] says whether a write went
  /// through, or null if that can't be read yet, which keeps it for next time.
  Future<void> checkEarlier(
    Future<bool?> Function(QueuedWrite write) check,
  ) async {
    final uid = _uid();
    final earlier = [
      for (final e in _queued.values)
        if (e.earlier && e.write.uid == uid) e,
    ];
    for (final entry in earlier) {
      final applied = await check(entry.write);
      if (applied == null || _queued[entry.write.path] != entry) continue;
      _queued.remove(entry.write.path);
      if (!applied) add(entry.write.what);
    }
    if (earlier.isNotEmpty) _save();
  }

  void _save() =>
      unawaited(_store?.write([for (final e in _queued.values) e.write]));
}

class _Entry {
  new(this.write, {this.id = -1, this.earlier = false});

  final QueuedWrite write;
  final int id;
  final bool earlier;
}

/// The refusals of this run of the app.
final refusedWrites = RefusedWrites();

/// Follows a write that goes out while offline: it returns at once and the
/// write is queued. If the server refuses it, [what] is reported.
void keepWrite(
  Future<void> write,
  String what, {
  String? path,
  Map<String, Object?> fields = const {},
  bool mustExist = true,
}) => refusedWrites.track(
  write,
  what,
  path: path,
  fields: fields,
  mustExist: mustExist,
);

extension KeepWrite on Future<void> {
  /// [keepWrite], for the end of a write chain.
  void keepOrReport(
    String what, {
    String? path,
    Map<String, Object?> fields = const {},
    bool mustExist = true,
  }) => keepWrite(this, what, path: path, fields: fields, mustExist: mustExist);
}
