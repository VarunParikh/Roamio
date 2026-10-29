import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_check.dart';

void main() {
  group('checkReleaseTag', () {
    test('accepts a tag that matches the pubspec version', () {
      final r = checkReleaseTag('v0.1.0', '0.1.0+1');
      expect(r.version, '0.1.0');
      expect(r.prerelease, isFalse);
    });

    test('a -suffix tag is a pre-release of the same version', () {
      final r = checkReleaseTag('v0.1.0-rc1', '0.1.0+1');
      expect(r.version, '0.1.0');
      expect(r.prerelease, isTrue);
    });

    test('rejects a tag that does not match the pubspec version', () {
      expect(
        () => checkReleaseTag('v0.2.0', '0.1.0+1'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('pubspec.yaml says 0.1.0'),
          ),
        ),
      );
    });

    test('rejects tags that are not vX.Y.Z', () {
      for (final tag in ['0.1.0', 'v0.1', 'v0.1.0.1', 'release', 'v0.1.0-']) {
        expect(
          () => checkReleaseTag(tag, '0.1.0+1'),
          throwsFormatException,
          reason: tag,
        );
      }
    });

    test('needs a build number in pubspec so Android sees an update', () {
      expect(() => checkReleaseTag('v0.1.0', '0.1.0'), throwsFormatException);
    });
  });

  group('pubspecVersion', () {
    test('reads the version line', () {
      expect(pubspecVersion('name: roamio\nversion: 1.2.3+4\n'), '1.2.3+4');
    });

    test('fails clearly when there is none', () {
      expect(() => pubspecVersion('name: roamio\n'), throwsFormatException);
    });
  });

  group('changelogNotes', () {
    const changelog = '''
# Changelog

## 0.2.0
- Second thing.

## [0.1.0] - 2026-11-01

- First release.
- Works offline.

## 0.0.9
- Old.
''';

    test('returns the section for the version, trimmed', () {
      expect(
        changelogNotes(changelog, '0.1.0'),
        '- First release.\n- Works offline.',
      );
      expect(changelogNotes(changelog, '0.2.0'), '- Second thing.');
    });

    test('returns null when the version has no section', () {
      expect(changelogNotes(changelog, '0.3.0'), isNull);
      expect(changelogNotes(changelog, '0.1'), isNull);
    });

    test('an empty section counts as none', () {
      expect(changelogNotes('## 0.4.0\n\n## 0.3.0\n- x\n', '0.4.0'), isNull);
    });
  });
}
