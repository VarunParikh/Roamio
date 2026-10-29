import 'package:roamio/core/images/photo_pipeline.dart';
import 'package:roamio/core/images/upload_queue.dart';

/// Hands out fake photo paths and records what would be uploaded.
class FakePhotoPipeline implements PhotoPipeline {
  final List<bool> picks = [];
  final List<String> queued = [];

  /// The size class of each queued photo, in the same order as [queued].
  final List<PhotoKind> kinds = [];

  /// When true, the next pick is cancelled.
  bool cancelNext = false;

  /// The picked file isn't an image the pipeline can read.
  bool unreadable = false;

  @override
  Future<String?> pick({required bool camera}) async {
    picks.add(camera);
    if (cancelNext) {
      cancelNext = false;
      return null;
    }
    return '/photos/${picks.length}.jpg';
  }

  @override
  Future<void> queueUpload({
    required String path,
    required PhotoKind kind,
    required String storageDir,
    required String docPath,
    required String field,
    required UploadMode mode,
  }) async {
    if (unreadable) throw const FormatException('not an image');
    queued.add('$path -> $storageDir ($docPath.$field ${mode.name})');
    kinds.add(kind);
  }
}
