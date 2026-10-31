import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/privacy/privacy_policy.dart';
import 'package:roamio/core/sync/refused_writes.dart';

/// What's sent to the crash log, once reports are allowed. While they aren't,
/// nothing leaves this class. Nothing here names a person or a tab.
class CrashLog {
  new({required this.send});

  final Future<void> Function(
    Object error,
    StackTrace stack, {
    required bool fatal,
  })
  send;

  /// Whether reports are allowed for whoever is signed in.
  bool on = false;

  void error(Object error, StackTrace stack) =>
      _send(error, stack, fatal: true);

  /// Flutter caught it and the app carries on, so it isn't a crash.
  void flutterError(FlutterErrorDetails details) =>
      _send(details.exception, details.stack ?? StackTrace.empty, fatal: false);

  /// The only sign on any server that the database refused a write (item 23).
  void refusedWrite() =>
      _send('Server refused a queued write', StackTrace.current, fatal: false);

  void _send(Object error, StackTrace stack, {required bool fatal}) {
    if (on) unawaited(send(error, stack, fatal: fatal));
  }
}

final crashLog = CrashLog(
  send: (error, stack, {required fatal}) =>
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal),
);

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
  void setEnabled({required bool on}) {
    crashLog.on = on;
    final crashlytics = FirebaseCrashlytics.instance;
    unawaited(crashlytics.setCrashlyticsCollectionEnabled(on));
    // A native crash while off waits on the phone: it must not go up later,
    // when someone else on this phone is allowed reports.
    if (!on) unawaited(crashlytics.deleteUnsentReports());
  }
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

/// Catches Flutter and platform errors and refused writes for the crash log.
void installCrashHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    crashLog.flutterError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crashLog.error(error, stack);
    return true;
  };
  refusedWrites.onRefused = (_) => crashLog.refusedWrite();
}
