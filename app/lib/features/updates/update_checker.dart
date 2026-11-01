import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:roamio/features/home/data/weather_client.dart' show FetchJson;

/// This build's version; must match `version:` in pubspec.yaml (a test
/// checks), so bump both when releasing.
const appVersion = '1.0.0';

const _latestRelease =
    'https://api.github.com/repos/VarunParikh/Roamio/releases/latest';
final Uri _releasesPage = Uri.parse(
  'https://github.com/VarunParikh/Roamio/releases/latest',
);

/// Compares `x.y.z` versions; a leading `v` and a `+build` are ignored.
int compareVersions(String a, String b) {
  List<int> parts(String v) => v
      .replaceFirst(RegExp('^v'), '')
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final x = parts(a);
  final y = parts(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

/// What the popup offers (UC-34).
class UpdateNotice {
  const new({
    required this.version,
    required this.notes,
    required this.downloadUrl,
    required this.blocking,
  });

  final String version;
  final String notes;
  final Uri downloadUrl;

  /// Below `min_supported_version`: the popup can't be dismissed.
  final bool blocking;
}

/// A small saved record: when GitHub was last asked, what it said, and the
/// version the person dismissed.
abstract interface class UpdateStore {
  Future<Map<String, Object?>> read();
  Future<void> write(Map<String, Object?> data);
}

/// Asks GitHub for the latest release at most once every 24 hours; any
/// failure stays quiet and is retried on the next launch.
class UpdateChecker {
  new(this._fetch, this._store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final FetchJson _fetch;
  final UpdateStore _store;
  final DateTime Function() _now;

  static const _every = Duration(hours: 24);

  Future<UpdateNotice?> check({
    required String current,
    required String minSupported,
  }) async {
    final data = await _store.read();
    var release = data['release'] as Map<String, Object?>?;
    final checked = DateTime.tryParse(data['checkedAt'] as String? ?? '');
    if (checked == null || _now().difference(checked) >= _every) {
      try {
        final json = (await _fetch(Uri.parse(_latestRelease)))! as Map;
        final apk = ((json['assets'] as List?) ?? const [])
            .cast<Map<Object?, Object?>>()
            .where((a) => '${a['name']}'.endsWith('.apk'))
            .firstOrNull;
        release = {
          'version': (json['tag_name']! as String).replaceFirst(
            RegExp('^v'),
            '',
          ),
          'notes': json['body'] as String? ?? '',
          'url': apk?['browser_download_url'] ?? json['html_url'],
        };
        await _store.write({
          ...data,
          'checkedAt': _now().toIso8601String(),
          'release': release,
        });
      } on Object {
        // Offline or GitHub unavailable: say nothing, try next launch.
      }
    }

    final version = release?['version'] as String?;
    final notice = UpdateNotice(
      version: version ?? minSupported,
      notes: release?['notes'] as String? ?? '',
      downloadUrl: switch (release?['url']) {
        final String url when url.isNotEmpty => Uri.parse(url),
        _ => _releasesPage,
      },
      blocking: compareVersions(current, minSupported) < 0,
    );
    if (notice.blocking) return notice;
    if (version == null || compareVersions(version, current) <= 0) return null;
    return data['dismissed'] == version ? null : notice;
  }

  /// "Later": don't offer [notice]'s version again.
  Future<void> dismiss(UpdateNotice notice) async {
    final data = await _store.read();
    await _store.write({...data, 'dismissed': notice.version});
  }
}

/// [UpdateStore] as a JSON file in the app's support folder.
class FileUpdateStore implements UpdateStore {
  Future<File> get _file async => File(
    '${(await getApplicationSupportDirectory()).path}/update_check.json',
  );

  @override
  Future<Map<String, Object?>> read() async {
    try {
      return (jsonDecode(await (await _file).readAsString()) as Map)
          .cast<String, Object?>();
    } on Object {
      return {};
    }
  }

  @override
  Future<void> write(Map<String, Object?> data) async {
    await (await _file).writeAsString(jsonEncode(data));
  }
}

final updateCheckerProvider = Provider<UpdateChecker>(
  (ref) => throw UnimplementedError('updateCheckerProvider must be overridden'),
);
