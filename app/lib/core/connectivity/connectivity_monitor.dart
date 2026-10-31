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
    this.reachOverHttps,
  });

  final String host;
  final Duration every;
  final Duration timeout;
  final int offlineAfter;
  final Future<List<InternetAddress>> Function(String host) lookup;

  /// The second opinion when DNS fails (item 18): whether Google's
  /// connectivity page answers. Only asked when DNS has failed.
  final Future<bool> Function()? reachOverHttps;

  @override
  Stream<bool> get changes {
    late final StreamController<bool> controller;
    Timer? timer;
    AppLifecycleListener? lifecycle;
    bool? last;
    var failures = 0;
    var polling = false;

    Future<void> poll() async {
      // A slow lookup must not pile up polls behind it (item 18): the next
      // one waits for this to finish, and the timer or resume picks it up.
      if (polling) return;
      polling = true;
      try {
        final found = await check();
        if (controller.isClosed) return;
        failures = found ? 0 : failures + 1;
        if (!found && failures < offlineAfter) return;
        if (found == last) return;
        last = found;
        controller.add(found);
      } finally {
        polling = false;
      }
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

  /// Online if DNS answers, or, when it doesn't, if the HTTPS check does.
  /// Some networks answer DNS wrongly while the internet works.
  @override
  Future<bool> check() async {
    if (await _dnsAnswers()) return true;
    final reach = reachOverHttps ?? _reachesOverHttps;
    return await reach().timeout(timeout, onTimeout: () => false);
  }

  Future<bool> _dnsAnswers() async {
    try {
      final found = await lookup(host).timeout(timeout);
      return found.isNotEmpty && found.first.rawAddress.isNotEmpty;
    } on Exception {
      return false;
    }
  }

  /// Google's connectivity page answers 204 with an empty body, so it costs
  /// almost no data.
  Future<bool> _reachesOverHttps() async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client
          .getUrl(Uri.parse('https://www.gstatic.com/generate_204'))
          .timeout(timeout);
      final response = await request.close().timeout(timeout);
      await response.drain<void>();
      return response.statusCode == 204;
    } on Exception {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
