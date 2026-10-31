import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/privacy/privacy_policy.dart';

/// Where app errors go. The Firebase one sends them to Crashlytics; tests and
/// the emulators use the quiet one (item 23).
abstract interface class CrashReporter {
  void setEnabled({required bool on});
}

class NoCrashReporter implements CrashReporter {
  const new();

  @override
  void setEnabled({required bool on}) {}
}

class FirebaseCrashReporter implements CrashReporter {
  const new();

  @override
  void setEnabled({required bool on}) => unawaited(
    FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(on),
  );
}

final crashReporterProvider = Provider<CrashReporter>(
  (ref) => const NoCrashReporter(),
);

/// Crash reports are sent only for a confirmed adult (privacy policy). Off
/// until the age is known, and switched off again for anyone else.
final crashCollectionProvider = Provider<void>((ref) {
  final allowed = ref.watch(privacyPolicyProvider).allowsCrashReports;
  ref.read(crashReporterProvider).setEnabled(on: allowed);
});

/// Catches Flutter and platform errors and passes them to Crashlytics. Their
/// reports are dropped unless [crashCollectionProvider] allows them.
void installCrashHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(FirebaseCrashlytics.instance.recordFlutterFatalError(details));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
    );
    return true;
  };
}
