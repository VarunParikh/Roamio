import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:roamio/core/images/upload_queue.dart';

/// How large a photo may stay (spec §10): bills keep more detail for OCR.
enum PhotoKind {
  photo(1600),
  bill(2048);

  new(this.maxSide);

  /// Longest side in pixels after compression.
  final int maxSide;
}

/// Picks, compresses and queues photos for upload (spec §10). Every photo
/// is shrunk, re-encoded as WebP quality 80 and stripped of EXIF (including
/// GPS) on the device, before anything leaves it.
abstract interface class PhotoPipeline {
  /// Lets the person take ([camera]) or choose a photo; null if cancelled.
  Future<String?> pick({required bool camera});

  /// Compresses [path] and queues it for `storageDir/<id>.webp`; once
  /// uploaded, its link is written to [docPath].[field]. Returns once queued,
  /// so it works offline.
  Future<void> queueUpload({
    required String path,
    required PhotoKind kind,
    required String storageDir,
    required String docPath,
    required String field,
    required UploadMode mode,
  });
}

/// Overridden in `main.dart`; tests use a fake.
final photoPipelineProvider = Provider<PhotoPipeline>(
  (ref) => throw UnimplementedError('photoPipelineProvider must be overridden'),
);

/// The size a [width] x [height] photo shrinks to so its longest side is
/// at most [maxSide], keeping its shape. Small photos are never enlarged.
(int, int) scaledSize(int width, int height, int maxSide) {
  final longest = max(width, height);
  if (longest <= maxSide) return (width, height);
  int scale(int side) => max(1, (side * maxSide / longest).round());
  return (scale(width), scale(height));
}

/// Compresses [path] into [target]: longest side at most [kind].maxSide,
/// WebP quality 80, no EXIF. Returns null if the image can't be read.
Future<File?> compressPhoto(String path, String target, PhotoKind kind) async {
  // Reads only the header for the size. The plugin scales until both
  // sides reach its limits, so passing the target's short side for both
  // puts the long side at the cap whichever way the camera stored it.
  final buffer = await ui.ImmutableBuffer.fromFilePath(path);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final (width, height) = scaledSize(
    descriptor.width,
    descriptor.height,
    kind.maxSide,
  );
  descriptor.dispose();
  buffer.dispose();
  final shortSide = min(width, height);
  final out = await FlutterImageCompress.compressAndGetFile(
    path,
    target,
    minWidth: shortSide,
    minHeight: shortSide,
    // Quality 80 and dropping EXIF (keepExif: false) are the plugin's
    // defaults; integration_test/photo_compression_test.dart proves both.
    format: CompressFormat.webp,
  );
  return out == null ? null : File(out.path);
}

String _newId() {
  final random = Random.secure();
  return List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join();
}

class DevicePhotoPipeline implements PhotoPipeline {
  new(this._queue, this._dir, {ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final UploadQueue _queue;
  final Directory _dir;
  final ImagePicker _picker;

  @override
  Future<String?> pick({required bool camera}) async =>
      (await _picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
      ))?.path;

  @override
  Future<void> queueUpload({
    required String path,
    required PhotoKind kind,
    required String storageDir,
    required String docPath,
    required String field,
    required UploadMode mode,
  }) async {
    final id = _newId();
    await _dir.create(recursive: true);
    final file = await compressPhoto(path, '${_dir.path}/$id.webp', kind);
    if (file == null) throw const FormatException('Not a readable photo');
    await _queue.enqueue(
      UploadJob(
        id: id,
        localPath: file.path,
        storagePath: '$storageDir/$id.webp',
        docPath: docPath,
        field: field,
        mode: mode,
      ),
    );
    unawaited(_queue.runDue());
  }
}

/// Keeps the queue in a JSON file in the app's private folder.
class FileUploadStore implements UploadStore {
  new(this._file);

  final File _file;

  @override
  Future<List<UploadJob>> load() async {
    if (!_file.existsSync()) return [];
    final list = jsonDecode(await _file.readAsString()) as List;
    return list.cast<Map<String, dynamic>>().map(UploadJob.fromJson).toList();
  }

  @override
  Future<void> save(List<UploadJob> jobs) async {
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode([for (final j in jobs) j.toJson()]));
    await tmp.rename(_file.path); // atomic, so a crash can't corrupt it
  }
}

class FirebaseUploader implements Uploader {
  new(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<String> upload(UploadJob job) async {
    final file = File(job.localPath);
    if (!file.existsSync()) throw const UploadFileMissing();
    final ref = _storage.ref(job.storagePath);
    try {
      await ref.putFile(file, SettableMetadata(contentType: 'image/webp'));
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized') throw const UploadRefused();
      rethrow;
    }
  }
}

class FirestoreUploadTarget implements UploadTarget {
  new(this._db);

  final FirebaseFirestore _db;

  @override
  Future<void> attach(UploadJob job, String url) async {
    try {
      await _db.doc(job.docPath).update({
        job.field: switch (job.mode) {
          UploadMode.append => FieldValue.arrayUnion([url]),
          UploadMode.replace => url,
        },
      });
    } on FirebaseException catch (e) {
      // No permission, or the tab or adventure is gone: never going to work.
      if (e.code == 'permission-denied' || e.code == 'not-found') {
        throw const UploadRefused();
      }
      rethrow;
    }
  }

  @override
  Future<void> discardLocal(UploadJob job) async {
    final file = File(job.localPath);
    if (file.existsSync()) await file.delete();
  }
}

/// Builds the real pipeline and keeps the queue moving: now, every 30
/// seconds while the app is open, and whenever it comes back to the front.
/// `flush` tries every waiting photo now, backoff or not (the Sync button).
/// [users] is the signed-in uid over time; signing out clears the queue.
Future<({PhotoPipeline pipeline, Future<void> Function() flush})>
startPhotoPipeline(
  FirebaseFirestore db,
  FirebaseStorage storage,
  Stream<String?> users,
) async {
  final dir = await getApplicationSupportDirectory();
  final queue = UploadQueue(
    store: FileUploadStore(File('${dir.path}/upload_queue.json')),
    uploader: FirebaseUploader(storage),
    target: FirestoreUploadTarget(db),
  );
  void run() => unawaited(queue.runDue().catchError((Object _) {}));
  run();
  Timer.periodic(const Duration(seconds: 30), (_) => run());
  AppLifecycleListener(onResume: run);
  clearOnSignOut(users, queue.clear);
  return (
    pipeline: DevicePhotoPipeline(
      queue,
      Directory('${dir.path}/pending_uploads'),
    ),
    flush: () => queue.runDue(ignoreBackoff: true),
  );
}
