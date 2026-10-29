import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every Remote Config key the app reads, with its in-app default, so the
/// app behaves the same when Remote Config can't be reached (spec §11).
/// Listed in `docs/REMOTE_CONFIG.md`.
const remoteConfigDefaults = <String, String>{
  'ocr_enabled': 'true',
  'weather_enabled': 'true',
  'export_enabled': 'true',
  'cta_pulse_enabled': 'true',
  'min_supported_version': '0.0.0',
  'category_order': '',
};

/// Where the values come from; Firebase in the app, a fake in tests.
abstract interface class RemoteConfigSource {
  /// The active values by key; throws when they can't be loaded.
  Future<Map<String, String>> load();
}

final remoteConfigSourceProvider = Provider<RemoteConfigSource>(
  (ref) =>
      throw UnimplementedError('remoteConfigSourceProvider must be overridden'),
);

/// The values as loaded; empty (so every default applies) on any failure.
final remoteValuesProvider = FutureProvider<Map<String, String>>((ref) async {
  try {
    return await ref.watch(remoteConfigSourceProvider).load();
  } on Object {
    return const {};
  }
});

/// The settings the app runs with.
class AppConfig {
  const new({
    required this.ocrEnabled,
    required this.weatherEnabled,
    required this.exportEnabled,
    required this.ctaPulse,
    required this.minSupportedVersion,
    required this.categoryOrder,
  });

  factory fromValues(Map<String, String> values) {
    String value(String key) => values[key] ?? remoteConfigDefaults[key]!;
    bool flag(String key) => switch (value(key).trim().toLowerCase()) {
      'true' => true,
      'false' => false,
      _ => remoteConfigDefaults[key] == 'true',
    };
    final version = value('min_supported_version').trim();
    return AppConfig(
      ocrEnabled: flag('ocr_enabled'),
      weatherEnabled: flag('weather_enabled'),
      exportEnabled: flag('export_enabled'),
      ctaPulse: flag('cta_pulse_enabled'),
      minSupportedVersion: RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)
          ? version
          : remoteConfigDefaults['min_supported_version']!,
      categoryOrder: [
        for (final id in value('category_order').split(','))
          if (id.trim().isNotEmpty) id.trim(),
      ],
    );
  }

  final bool ocrEnabled;
  final bool weatherEnabled;
  final bool exportEnabled;

  /// Whether the primary button breathes on empty screens (spec §12).
  final bool ctaPulse;

  /// Below this the app asks for an update and can't be used (Task 38).
  final String minSupportedVersion;

  /// Category ids to list first, in this order; the rest follow.
  final List<String> categoryOrder;
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromValues(ref.watch(remoteValuesProvider).value ?? {}),
);

/// Firebase Remote Config: fetched at most every 12 hours and never waited
/// on for long, since every key has a default.
class FirebaseRemoteConfigSource implements RemoteConfigSource {
  new(this._config);

  final FirebaseRemoteConfig _config;

  @override
  Future<Map<String, String>> load() async {
    await _config.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 12),
      ),
    );
    await _config.setDefaults(remoteConfigDefaults);
    try {
      await _config.fetchAndActivate();
    } on Exception {
      // Offline or unreachable: last fetched values, else the defaults.
    }
    return {
      for (final MapEntry(:key, :value) in _config.getAll().entries)
        key: value.asString(),
    };
  }
}
