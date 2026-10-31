import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/connectivity/connectivity_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Answers each lookup from [answers] in turn, repeating the last.
  ConnectivityMonitor monitor(List<bool> answers) {
    var i = 0;
    return DeviceConnectivityMonitor(
      every: const Duration(milliseconds: 5),
      lookup: (_) async {
        final ok = answers[i < answers.length ? i : answers.length - 1];
        i++;
        if (!ok) throw const SocketException('no answer');
        return [InternetAddress.loopbackIPv4];
      },
    );
  }

  Future<List<bool>> collect(ConnectivityMonitor m) async {
    final seen = <bool>[];
    final subscription = m.changes.listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await subscription.cancel();
    return seen;
  }

  group('DeviceConnectivityMonitor (spec UC-31)', () {
    test('one or two failed lookups are not going offline', () async {
      final seen = await collect(monitor([true, false, false, true]));
      expect(seen, [true]);
    });

    test('several in a row are', () async {
      final seen = await collect(monitor([true, false, false, false]));
      expect(seen, [true, false]);
    });

    test('the first good answer means back online', () async {
      final seen = await collect(monitor([false, false, false, true]));
      expect(seen, [false, true]);
    });

    test('a lookup that hangs counts as failed, not as an error', () async {
      final m = DeviceConnectivityMonitor(
        timeout: const Duration(milliseconds: 5),
        lookup: (_) => Completer<List<InternetAddress>>().future,
      );
      expect(await m.check(), isFalse);
    });
  });

  test('a slow lookup never has two polls running at once (item 18)', () async {
    var running = 0;
    var mostAtOnce = 0;
    final monitor = DeviceConnectivityMonitor(
      every: const Duration(milliseconds: 10),
      timeout: const Duration(seconds: 1),
      lookup: (_) async {
        running++;
        mostAtOnce = running > mostAtOnce ? running : mostAtOnce;
        await Future<void>.delayed(const Duration(milliseconds: 60));
        running--;
        return [InternetAddress('142.250.0.1')];
      },
    );
    final sub = monitor.changes.listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await sub.cancel();
    expect(mostAtOnce, 1);
  });

  group('when DNS fails but the internet works (item 18)', () {
    Future<List<InternetAddress>> dnsDown(String _) async =>
        throw const SocketException('no answer');

    test('online when the HTTPS check gets through', () async {
      var probes = 0;
      final monitor = DeviceConnectivityMonitor(
        lookup: dnsDown,
        reachOverHttps: () async {
          probes++;
          return true;
        },
      );
      expect(await monitor.check(), isTrue);
      expect(probes, 1);
    });

    test('offline only when both checks fail', () async {
      final monitor = DeviceConnectivityMonitor(
        lookup: dnsDown,
        reachOverHttps: () async => false,
      );
      expect(await monitor.check(), isFalse);
    });

    test('a stuck HTTPS check counts as failed, within the timeout', () async {
      final monitor = DeviceConnectivityMonitor(
        lookup: dnsDown,
        timeout: const Duration(milliseconds: 5),
        reachOverHttps: () => Completer<bool>().future,
      );
      expect(await monitor.check(), isFalse);
    });

    test('the HTTPS check is not needed when DNS answers', () async {
      var probes = 0;
      final monitor = DeviceConnectivityMonitor(
        lookup: (_) async => [InternetAddress('142.250.0.1')],
        reachOverHttps: () async {
          probes++;
          return false;
        },
      );
      expect(await monitor.check(), isTrue);
      expect(probes, 0);
    });
  });
}
