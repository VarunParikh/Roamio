import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this phone can reach the internet (spec §5.10).
abstract interface class ConnectivityMonitor {
  /// Emits each time the answer changes.
  Stream<bool> get changes;

  /// The answer right now.
  Future<bool> check();
}

/// Always connected. The default, so screens built in tests stay online.
class AlwaysOnline implements ConnectivityMonitor {
  const new();

  @override
  Stream<bool> get changes => const Stream.empty();

  @override
  Future<bool> check() async => true;
}

/// Overridden in `main.dart` with [DeviceConnectivityMonitor].
final connectivityMonitorProvider = Provider<ConnectivityMonitor>(
  (ref) => const AlwaysOnline(),
);

/// Asks DNS for Google's servers every few seconds, and when the app comes
/// back to the front. A phone on Wi-Fi with no internet counts as offline,
/// which a "connected to a network" flag would miss. Mobile data often misses
/// a lookup, so going offline takes [offlineAfter] failures in a row; one good
/// answer means back online.
class DeviceConnectivityMonitor implements ConnectivityMonitor {
  new({
    this.host = 'firestore.googleapis.com',
    this.every = const Duration(seconds: 5),
    this.timeout = const Duration(seconds: 5),
    this.offlineAfter = 3,
    this.lookup = InternetAddress.lookup,
  });

  final String host;
  final Duration every;
  final Duration timeout;
  final int offlineAfter;
  final Future<List<InternetAddress>> Function(String host) lookup;

  @override
  Stream<bool> get changes {
    late final StreamController<bool> controller;
    Timer? timer;
    AppLifecycleListener? lifecycle;
    bool? last;
    var failures = 0;

    Future<void> poll() async {
      final found = await check();
      if (controller.isClosed) return;
      failures = found ? 0 : failures + 1;
      if (!found && failures < offlineAfter) return;
      if (found == last) return;
      last = found;
      controller.add(found);
    }

    controller = StreamController<bool>(
      onListen: () {
        unawaited(poll());
        timer = Timer.periodic(every, (_) => unawaited(poll()));
        lifecycle = AppLifecycleListener(onResume: () => unawaited(poll()));
      },
      onCancel: () {
        timer?.cancel();
        lifecycle?.dispose();
      },
    );
    return controller.stream;
  }

  @override
  Future<bool> check() async {
    try {
      final found = await lookup(host).timeout(timeout);
      return found.isNotEmpty && found.first.rawAddress.isNotEmpty;
    } on Exception {
      return false;
    }
  }
}
