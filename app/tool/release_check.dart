// Release helpers for .github/workflows/release.yml. Run from app/:
//   fvm dart run tool/release_check.dart check v0.1.0   # prints version= and prerelease=
//   fvm dart run tool/release_check.dart notes 0.1.0    # prints CHANGELOG notes, or nothing
import 'dart:io';

/// What a release tag means once it has been checked against pubspec.yaml.
typedef ReleaseTag = ({String version, bool prerelease});

final _tag = RegExp(r'^v(\d+\.\d+\.\d+)(-[0-9A-Za-z.]+)?$');

/// Checks [tag] (`vX.Y.Z`, or `vX.Y.Z-rc1` for a pre-release) against the
/// pubspec [version] (`X.Y.Z+build`). Throws a plain-language
/// [FormatException] when they don't fit together.
ReleaseTag checkReleaseTag(String tag, String version) {
  final m = _tag.firstMatch(tag);
  if (m == null) {
    throw FormatException(
      'Tag "$tag" is not like v1.2.3 (or v1.2.3-rc1 for a test release).',
    );
  }
  final parts = version.split('+');
  if (parts.length != 2 || int.tryParse(parts[1]) == null) {
    throw FormatException(
      'pubspec.yaml version "$version" needs a build number, like 1.2.3+4. '
      'Raise the number after + on every release so phones accept the update.',
    );
  }
  if (m[1] != parts[0]) {
    throw FormatException(
      'Tag "$tag" is for ${m[1]} but pubspec.yaml says ${parts[0]}. '
      'Bump the version in pubspec.yaml and update_checker.dart first.',
    );
  }
  return (version: m[1]!, prerelease: m[2] != null);
}

/// The `version:` value in a pubspec.yaml.
String pubspecVersion(String pubspec) {
  final m = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
  if (m == null) throw const FormatException('pubspec.yaml has no version.');
  return m[1]!;
}

/// The notes under `## X.Y.Z` (or `## [X.Y.Z] - date`) in a CHANGELOG, up to
/// the next `## ` heading; null when there is no such section or it is empty.
String? changelogNotes(String changelog, String version) {
  final heading = RegExp(
    '^## \\[?${RegExp.escape(version)}\\]?(?:[ \\t].*)?\$',
    multiLine: true,
  );
  final start = heading.firstMatch(changelog);
  if (start == null) return null;
  final rest = changelog.substring(start.end);
  final next = RegExp('^## ', multiLine: true).firstMatch(rest);
  final body = (next == null ? rest : rest.substring(0, next.start)).trim();
  return body.isEmpty ? null : body;
}

void main(List<String> args) {
  try {
    switch (args) {
      case ['check', final tag]:
        final pubspec = File('pubspec.yaml').readAsStringSync();
        final r = checkReleaseTag(tag, pubspecVersion(pubspec));
        stdout
          ..writeln('version=${r.version}')
          ..writeln('prerelease=${r.prerelease}');
      case ['notes', final version]:
        final file = File('../CHANGELOG.md');
        final notes = file.existsSync()
            ? changelogNotes(file.readAsStringSync(), version)
            : null;
        if (notes != null) stdout.writeln(notes);
      default:
        stderr.writeln('Usage: release_check.dart check <tag> | notes <x.y.z>');
        exitCode = 64;
    }
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  }
}
