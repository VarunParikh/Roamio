import 'dart:async';

/// How an uploaded photo's link is written to its document.
enum UploadMode {
  /// Added to a list field, such as a tab's `memories`.
  append,

  /// Replaces a single field, such as an adventure's `bannerUrl`.
  replace,
}

/// One compressed photo waiting to upload (spec §10).
class UploadJob {
  const new({
    required this.id,
    required this.localPath,
    required this.storagePath,
    required this.docPath,
    required this.field,
    required this.mode,
    this.attempts = 0,
    this.nextTryAt,
  });

  factory fromJson(Map<String, dynamic> json) => UploadJob(
    id: json['id'] as String,
    localPath: json['localPath'] as String,
    storagePath: json['storagePath'] as String,
    docPath: json['docPath'] as String,
    field: json['field'] as String,
    mode: UploadMode.values.byName(json['mode'] as String),
    attempts: json['attempts'] as int? ?? 0,
    nextTryAt: switch (json['nextTryAt']) {
      final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      _ => null,
    },
  );

  final String id;

  /// The compressed WebP, kept in the app's own folder until uploaded.
  final String localPath;
  final String storagePath;

  /// The Firestore document and field that get the download link.
  final String docPath;
  final String field;
  final UploadMode mode;
  final int attempts;
  final DateTime? nextTryAt;

  UploadJob copyWith({int? attempts, DateTime? nextTryAt}) => UploadJob(
    id: id,
    localPath: localPath,
    storagePath: storagePath,
    docPath: docPath,
    field: field,
    mode: mode,
    attempts: attempts ?? this.attempts,
    nextTryAt: nextTryAt ?? this.nextTryAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'localPath': localPath,
    'storagePath': storagePath,
    'docPath': docPath,
    'field': field,
    'mode': mode.name,
    'attempts': attempts,
    'nextTryAt': nextTryAt?.millisecondsSinceEpoch,
  };
}

/// Where the queue is kept between app runs.
abstract interface class UploadStore {
  Future<List<UploadJob>> load();
  Future<void> save(List<UploadJob> jobs);
}

/// The local photo is gone (app data cleared), so the job can never succeed.
class UploadFileMissing implements Exception {
  const new();
}

abstract interface class Uploader {
  /// Uploads the job's file and returns its download link.
  Future<String> upload(UploadJob job);
}

abstract interface class UploadTarget {
  /// Writes [url] to the job's document field.
  Future<void> attach(UploadJob job, String url);

  /// Deletes the local copy once it's no longer needed.
  Future<void> discardLocal(UploadJob job);
}

/// Uploads photos in order, keeping failed ones and retrying with a
/// doubling delay, so photos added offline go up later — even after the
/// app restarts (spec §10).
class UploadQueue {
  new({
    required this._store,
    required this._uploader,
    required this._target,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final UploadStore _store;
  final Uploader _uploader;
  final UploadTarget _target;
  final DateTime Function() _clock;
  Future<void> _running = Future.value();

  /// 5 s after the first failure, doubling each time, at most 30 minutes.
  static Duration backoffFor(int attempts) {
    const max = Duration(minutes: 30);
    if (attempts > 20) return max;
    final delay = const Duration(seconds: 5) * (1 << (attempts - 1));
    return delay > max ? max : delay;
  }

  Future<void> enqueue(UploadJob job) => _serial(() async {
    await _store.save([...await _store.load(), job]);
  });

  /// Tries every job that is due; failed ones wait for their backoff. With
  /// [ignoreBackoff] (the person pressed Sync) it tries all of them now.
  Future<void> runDue({bool ignoreBackoff = false}) => _serial(() async {
    final jobs = await _store.load();
    final remaining = <UploadJob>[];
    for (final job in jobs) {
      final due =
          ignoreBackoff ||
          job.nextTryAt == null ||
          !job.nextTryAt!.isAfter(_clock());
      if (!due) {
        remaining.add(job);
        continue;
      }
      try {
        final url = await _uploader.upload(job);
        await _target.attach(job, url);
        await _target.discardLocal(job);
      } on UploadFileMissing {
        // Nothing left to upload; drop it.
      } on Exception {
        final attempts = job.attempts + 1;
        remaining.add(
          job.copyWith(
            attempts: attempts,
            nextTryAt: _clock().add(backoffFor(attempts)),
          ),
        );
      }
    }
    await _store.save(remaining);
  });

  /// Runs one change at a time so overlapping calls can't lose jobs. A
  /// failing call reports its error but doesn't block later ones.
  Future<void> _serial(Future<void> Function() body) {
    final next = _running.then((_) => body());
    _running = next.catchError((Object _) {});
    return next;
  }
}
