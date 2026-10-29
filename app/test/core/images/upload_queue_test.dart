import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/images/upload_queue.dart';

/// Keeps jobs in memory, standing in for the file on disk.
class MemoryStore implements UploadStore {
  List<UploadJob> saved = [];
  bool failNextLoad = false;

  @override
  Future<List<UploadJob>> load() async {
    if (failNextLoad) {
      failNextLoad = false;
      throw Exception('disk full');
    }
    return [...saved];
  }

  @override
  Future<void> save(List<UploadJob> jobs) async => saved = [...jobs];
}

class FakeUploader implements Uploader {
  final List<String> uploaded = [];
  final Set<String> missing = {};
  int failuresLeft = 0;

  @override
  Future<String> upload(UploadJob job) async {
    if (missing.contains(job.localPath)) throw const UploadFileMissing();
    if (failuresLeft > 0) {
      failuresLeft--;
      throw Exception('offline');
    }
    uploaded.add(job.storagePath);
    return 'https://files.example/${job.storagePath}';
  }
}

class FakeDocs implements UploadTarget {
  final List<String> writes = [];
  final List<String> cleaned = [];

  @override
  Future<void> attach(UploadJob job, String url) async =>
      writes.add('${job.mode.name} ${job.docPath}.${job.field} = $url');

  @override
  Future<void> discardLocal(UploadJob job) async => cleaned.add(job.localPath);
}

UploadJob _job(String id, {UploadMode mode = UploadMode.append}) => UploadJob(
  id: id,
  localPath: '/pending/$id.webp',
  storagePath: 'adventures/a1/tabs/t1/$id.webp',
  docPath: 'adventures/a1/tabs/t1',
  field: 'memories',
  mode: mode,
);

void main() {
  late MemoryStore store;
  late FakeUploader uploader;
  late FakeDocs docs;
  var now = DateTime(2026, 10, 29, 12);

  UploadQueue queue() => UploadQueue(
    store: store,
    uploader: uploader,
    target: docs,
    clock: () => now,
  );

  setUp(() {
    store = MemoryStore();
    uploader = FakeUploader();
    docs = FakeDocs();
    now = DateTime(2026, 10, 29, 12);
  });

  group('UploadQueue (spec §10: queue offline, retry with backoff)', () {
    test('uploads, attaches the link, then forgets the job', () async {
      final q = queue();
      await q.enqueue(_job('m1'));
      await q.runDue();

      expect(uploader.uploaded, ['adventures/a1/tabs/t1/m1.webp']);
      const url = 'https://files.example/adventures/a1/tabs/t1/m1.webp';
      expect(docs.writes, ['append adventures/a1/tabs/t1.memories = $url']);
      expect(docs.cleaned, ['/pending/m1.webp']);
      expect(store.saved, isEmpty);
    });

    test('keeps a failed job and backs off before retrying', () async {
      uploader.failuresLeft = 2;
      final q = queue();
      await q.enqueue(_job('m1'));

      await q.runDue();
      expect(store.saved.single.attempts, 1);
      expect(store.saved.single.nextTryAt, now.add(UploadQueue.backoffFor(1)));

      // Not due yet: nothing happens.
      await q.runDue();
      expect(store.saved.single.attempts, 1);

      now = now.add(UploadQueue.backoffFor(1));
      await q.runDue();
      expect(store.saved.single.attempts, 2);

      now = now.add(UploadQueue.backoffFor(2));
      await q.runDue();
      expect(store.saved, isEmpty);
      expect(docs.writes, hasLength(1));
    });

    test('backoff doubles from 5 seconds up to 30 minutes', () {
      expect(UploadQueue.backoffFor(1), const Duration(seconds: 5));
      expect(UploadQueue.backoffFor(2), const Duration(seconds: 10));
      expect(UploadQueue.backoffFor(5), const Duration(seconds: 80));
      expect(UploadQueue.backoffFor(20), const Duration(minutes: 30));
    });

    test('survives an app restart', () async {
      uploader.failuresLeft = 1;
      await queue().enqueue(_job('m1'));
      await queue().runDue(); // fails once

      now = now.add(const Duration(minutes: 1));
      final restarted = queue();
      await restarted.runDue();
      expect(uploader.uploaded, hasLength(1));
      expect(store.saved, isEmpty);
    });

    test('drops a job whose photo file has gone, and carries on', () async {
      uploader.missing.add('/pending/m1.webp');
      final q = queue();
      await q.enqueue(_job('m1'));
      await q.enqueue(_job('m2', mode: UploadMode.replace));
      await q.runDue();

      expect(uploader.uploaded, ['adventures/a1/tabs/t1/m2.webp']);
      expect(docs.writes.single, startsWith('replace '));
      expect(store.saved, isEmpty);
    });

    test('jobs round-trip through JSON for the file on disk', () {
      final job = _job('m1').copyWith(attempts: 3, nextTryAt: now);
      final back = UploadJob.fromJson(job.toJson());
      expect(back.id, 'm1');
      expect(back.mode, UploadMode.append);
      expect(back.attempts, 3);
      expect(back.nextTryAt, now);
      expect(back.storagePath, job.storagePath);
    });

    test('one failed call does not block the ones after it', () async {
      final q = queue();
      store.failNextLoad = true;
      await expectLater(q.enqueue(_job('m1')), throwsException);
      await q.enqueue(_job('m2'));
      await q.runDue();
      expect(uploader.uploaded, ['adventures/a1/tabs/t1/m2.webp']);
    });
  });
}
