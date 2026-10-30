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
    this.uploadedUrl,
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
    uploadedUrl: json['uploadedUrl'] as String?,
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

  /// Set once the file is up, so a retry only writes the link: Storage
  /// never lets a file be uploaded over.
  final String? uploadedUrl;

  UploadJob copyWith({
    int? attempts,
    DateTime? nextTryAt,
    String? uploadedUrl,
  }) => UploadJob(
    id: id,
    localPath: localPath,
    storagePath: storagePath,
    docPath: docPath,
    field: field,
    mode: mode,
    attempts: attempts ?? this.attempts,
    nextTryAt: nextTryAt ?? this.nextTryAt,
    uploadedUrl: uploadedUrl ?? this.uploadedUrl,
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
    'uploadedUrl': uploadedUrl,
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

/// The server refused the photo or its link for good (no permission, or
/// the tab is gone), so retrying can't help.
class UploadRefused implements Exception {
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
      var current = job;
      try {
        final url = current.uploadedUrl ?? await _uploader.upload(current);
        current = current.copyWith(uploadedUrl: url);
        await _target.attach(current, url);
        await _target.discardLocal(current);
      } on UploadFileMissing {
        // Nothing left to upload; drop it.
      } on UploadRefused {
        await _target.discardLocal(current);
      } on Exception {
        // No cap on attempts: a long offline trip must not lose photos.
        final attempts = current.attempts + 1;
        remaining.add(
          current.copyWith(
            attempts: attempts,
            nextTryAt: _clock().add(backoffFor(attempts)),
          ),
        );
      }
    }
    await _store.save(remaining);
  });

  /// Forgets every waiting photo and its local copy (on signing out, so
  /// the next person on this phone never uploads them).
  Future<void> clear() => _serial(() async {
    for (final job in await _store.load()) {
      await _target.discardLocal(job);
    }
    await _store.save(const []);
  });

  /// Runs one change at a time so overlapping calls can't lose jobs. A
  /// failing call reports its error but doesn't block later ones.
  Future<void> _serial(Future<void> Function() body) {
    final next = _running.then((_) => body());
    _running = next.catchError((Object _) {});
    return next;
  }
}

/// Runs [clear] each time someone who was signed in signs out (a session
/// [users] stream of uids). Starting signed out clears nothing.
StreamSubscription<String?> clearOnSignOut(
  Stream<String?> users,
  Future<void> Function() clear,
) {
  String? last;
  return users.listen((uid) {
    if (last != null && uid == null) {
      unawaited(clear().catchError((Object _) {}));
    }
    last = uid;
  });
}
