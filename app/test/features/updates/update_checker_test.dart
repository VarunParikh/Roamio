import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/updates/update_checker.dart';

import '../../support/fake_update_store.dart';

Map<String, Object?> _release(String tag) => {
  'tag_name': tag,
  'body': 'Faster Split screen.',
  'html_url': 'https://github.com/VarunParikh/Roamio/releases/tag/$tag',
  'assets': [
    {
      'name': 'roamio-$tag.apk',
      'browser_download_url': 'https://github.com/x/roamio-$tag.apk',
    },
  ],
};

void main() {
  group('versions', () {
    test('compares x.y.z numbers, ignoring a leading v and build numbers', () {
      expect(compareVersions('1.2.10', '1.2.9'), greaterThan(0));
      expect(compareVersions('v0.2.0', '0.10.0'), lessThan(0));
      expect(compareVersions('1.0.0+7', '1.0.0'), 0);
    });

    test(
      'appVersion matches pubspec.yaml, so a release bump can’t miss it',
      () {
        final pubspec = File('pubspec.yaml').readAsStringSync();
        final declared = RegExp(
          r'^version:\s*([0-9.]+)',
          multiLine: true,
        ).firstMatch(pubspec)!.group(1);
        expect(appVersion, declared);
      },
    );
  });

  group('UpdateChecker (UC-34)', () {
    final start = DateTime(2026, 10, 29, 9);

    UpdateChecker checker(
      List<Uri> asked,
      FakeUpdateStore store, {
      DateTime? at,
      String tag = 'v0.2.0',
      bool down = false,
    }) => UpdateChecker(
      (uri) async {
        asked.add(uri);
        if (down) throw Exception('offline');
        return _release(tag);
      },
      store,
      now: () => at ?? start,
    );

    test('offers a newer release with its notes and the APK link', () async {
      final asked = <Uri>[];
      final notice = await checker(
        asked,
        FakeUpdateStore(),
      ).check(current: '0.1.0', minSupported: '0.0.0');

      expect(notice?.version, '0.2.0');
      expect(notice?.notes, 'Faster Split screen.');
      expect(notice?.downloadUrl.toString(), endsWith('roamio-v0.2.0.apk'));
      expect(notice?.blocking, isFalse);
      expect(
        asked.single.toString(),
        'https://api.github.com/repos/VarunParikh/Roamio/releases/latest',
      );
    });

    test('nothing when up to date', () async {
      final notice = await checker(
        [],
        FakeUpdateStore(),
        tag: 'v0.1.0',
      ).check(current: '0.1.0', minSupported: '0.0.0');
      expect(notice, isNull);
    });

    test('asks GitHub at most once every 24 hours', () async {
      final asked = <Uri>[];
      final store = FakeUpdateStore();
      await checker(
        asked,
        store,
      ).check(current: '0.1.0', minSupported: '0.0.0');
      await checker(
        asked,
        store,
        at: start.add(const Duration(hours: 23)),
      ).check(current: '0.1.0', minSupported: '0.0.0');
      expect(asked, hasLength(1));

      await checker(
        asked,
        store,
        at: start.add(const Duration(hours: 25)),
      ).check(current: '0.1.0', minSupported: '0.0.0');
      expect(asked, hasLength(2));
    });

    test('a dismissed version isn’t offered again', () async {
      final store = FakeUpdateStore();
      final c = checker([], store);
      final notice = await c.check(current: '0.1.0', minSupported: '0.0.0');
      await c.dismiss(notice!);

      expect(
        await checker(
          [],
          store,
          at: start.add(const Duration(days: 2)),
        ).check(current: '0.1.0', minSupported: '0.0.0'),
        isNull,
      );
    });

    test('below min_supported_version it blocks: even dismissed, '
        'throttled or offline', () async {
      final store = FakeUpdateStore();
      final first = await checker(
        [],
        store,
      ).check(current: '0.1.0', minSupported: '0.0.0');
      await checker([], store).dismiss(first!);

      final blocked = await checker(
        [],
        store,
        at: start.add(const Duration(hours: 1)),
        down: true,
      ).check(current: '0.1.0', minSupported: '0.2.0');

      expect(blocked?.blocking, isTrue);
      expect(blocked?.version, '0.2.0');
      expect(blocked?.downloadUrl.toString(), endsWith('roamio-v0.2.0.apk'));
    });

    test(
      'blocked with nothing known yet: points at the releases page',
      () async {
        final blocked = await checker(
          [],
          FakeUpdateStore(),
          down: true,
        ).check(current: '0.1.0', minSupported: '0.2.0');
        expect(blocked?.blocking, isTrue);
        expect(
          blocked?.downloadUrl.toString(),
          'https://github.com/VarunParikh/Roamio/releases/latest',
        );
      },
    );

    test('a failed check stays quiet and tries again next launch', () async {
      final asked = <Uri>[];
      final store = FakeUpdateStore();
      expect(
        await checker(
          asked,
          store,
          down: true,
        ).check(current: '0.1.0', minSupported: '0.0.0'),
        isNull,
      );
      await checker(
        asked,
        store,
      ).check(current: '0.1.0', minSupported: '0.0.0');
      expect(asked, hasLength(2));
    });
  });
}
