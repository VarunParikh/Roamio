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
}
