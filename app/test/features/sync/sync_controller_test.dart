import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/connectivity/connectivity_monitor.dart';
import 'package:roamio/core/sync/refused_writes.dart';
import 'package:roamio/features/sync/sync_controller.dart';

import '../../support/fake_sync.dart';

void main() {
  late FakeConnectivity connectivity;
  late FakeNetworkSwitch network;
  late List<String> photoRuns;
  late ProviderContainer container;

  Future<void> start({required bool online}) async {
    connectivity = FakeConnectivity(online: online);
    network = FakeNetworkSwitch();
    photoRuns = [];
    container = ProviderContainer(
      overrides: [
        connectivityMonitorProvider.overrideWithValue(connectivity),
        networkSwitchProvider.overrideWithValue(network),
        photoFlushProvider.overrideWithValue(
          () async => photoRuns.add('photos'),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(syncControllerProvider, (_, _) {});
    await container.read(syncControllerProvider.notifier).ready;
  }

  SyncPhase phase() => container.read(syncControllerProvider).phase;

  test(
    'a drop mid-sync shows offline, and coming back online recovers (item 9)',
    () async {
      await start(online: true);
      network.hold = Completer<void>(); // the writes never finish while offline
      unawaited(container.read(syncControllerProvider.notifier).sync());
      await Future<void>.delayed(Duration.zero);
      expect(phase(), SyncPhase.syncing);

      connectivity.set(online: false);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(phase(), SyncPhase.offline);

      network.hold = null;
      connectivity.set(online: true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(phase(), SyncPhase.synced);
    },
  );

  setUp(refusedWrites.clear);

  test(
    'a refused offline change is reported, not called synced (item 2)',
    () async {
      await start(online: true);
      refusedWrites.add('a tab');
      await container.read(syncControllerProvider.notifier).sync();
      expect(phase(), SyncPhase.failed);
      expect(container.read(syncControllerProvider).error, contains('a tab'));
      expect(refusedWrites.refused.value, isEmpty);
    },
  );

  test('a refusal shows at once, even when no sync runs (item 2)', () async {
    await start(online: true);
    refusedWrites.add('a pal');
    expect(phase(), SyncPhase.failed);
    expect(container.read(syncControllerProvider).error, contains('a pal'));
  });

  test('online at start: normal, and the network is switched on', () async {
    await start(online: true);
    expect(phase(), SyncPhase.online);
    // Firestore's switch lives outside Flutter, so an earlier run may have
    // left it off (see the restart test below).
    expect(network.calls, ['enable']);
  });

  test('reopened online after going offline: the network comes back on, '
      'so nothing stays stuck on the phone', () async {
    // Firestore keeps its on/off state while the app's process lives, even
    // when Flutter restarts (Back out while offline, reopen when online).
    final firestore = _PersistentSwitch();
    ProviderContainer run({required bool online}) {
      final c = ProviderContainer(
        overrides: [
          connectivityMonitorProvider.overrideWithValue(
            FakeConnectivity(online: online),
          ),
          networkSwitchProvider.overrideWithValue(firestore),
          photoFlushProvider.overrideWithValue(() async {}),
        ],
      )..listen(syncControllerProvider, (_, _) {});
      return c;
    }

    final first = run(online: false);
    await first.read(syncControllerProvider.notifier).ready;
    expect(firestore.enabled, isFalse);
    first.dispose();

    final second = run(online: true);
    addTearDown(second.dispose);
    await second.read(syncControllerProvider.notifier).ready;
    expect(second.read(syncControllerProvider).phase, SyncPhase.online);
    expect(firestore.enabled, isTrue);
  });

  test('offline at start: Firestore goes to offline mode', () async {
    await start(online: false);
    expect(phase(), SyncPhase.offline);
    expect(network.calls, ['disable']);
  });

  test('losing the connection switches to offline mode', () async {
    await start(online: true);
    connectivity.set(online: false);
    await pumpEventQueue();
    expect(phase(), SyncPhase.offline);
    // 'enable' is from starting online.
    expect(network.calls, ['enable', 'disable']);
  });

  test('coming back syncs by itself: network, writes and photos', () async {
    await start(online: false);
    connectivity.set(online: true);
    await pumpEventQueue();
    expect(phase(), SyncPhase.synced);
    expect(network.calls, ['disable', 'enable', 'writes']);
    expect(photoRuns, ['photos']);
  });

  test('only really being offline counts as offline', () async {
    await start(online: false);
    expect(container.read(isOfflineProvider), isTrue);

    network.failWrites = Exception('permission-denied');
    connectivity.set(online: true);
    await pumpEventQueue();
    // A failed sync with a connection isn't a reason to switch buttons off.
    expect(phase(), SyncPhase.failed);
    expect(container.read(isOfflineProvider), isFalse);
  });

  test('blips that never went offline do not ask for a sync', () async {
    await start(online: true);
    connectivity.set(online: true);
    await pumpEventQueue();
    expect(phase(), SyncPhase.online);
  });

  test('Try again re-enables the network and uploads again', () async {
    await start(online: false);
    await container.read(syncControllerProvider.notifier).sync();

    expect(phase(), SyncPhase.synced);
    expect(network.calls, ['disable', 'enable', 'writes']);
    expect(photoRuns, ['photos']);
  });

  test('a failed sync shows the error and can be retried', () async {
    await start(online: false);
    network.failWrites = Exception('permission-denied');
    connectivity.set(online: true);
    await pumpEventQueue();

    final notifier = container.read(syncControllerProvider.notifier);
    final failed = container.read(syncControllerProvider);
    expect(failed.phase, SyncPhase.failed);
    expect(failed.error, isNotEmpty);

    await notifier.sync();
    expect(phase(), SyncPhase.synced);
  });

  test('dropping offline mid-sync ends offline, not failed', () async {
    await start(online: false);
    network.failWrites = Exception('unavailable');
    connectivity.online = false;

    await container.read(syncControllerProvider.notifier).sync();

    expect(phase(), SyncPhase.offline);
    expect(network.calls.last, 'disable');
  });

  test('dismissing "Synced" returns to normal', () async {
    await start(online: false);
    connectivity.set(online: true);
    await pumpEventQueue();
    container.read(syncControllerProvider.notifier).dismissSynced();

    expect(phase(), SyncPhase.online);
  });

  test('a second tap while syncing does nothing', () async {
    await start(online: false);
    final notifier = container.read(syncControllerProvider.notifier);

    await Future.wait([notifier.sync(), notifier.sync()]);

    expect(network.calls.where((c) => c == 'enable'), hasLength(1));
  });
}

/// Firestore's network switch, which outlives a Flutter restart.
class _PersistentSwitch implements NetworkSwitch {
  bool enabled = true;

  @override
  Future<void> disable() async => enabled = false;

  @override
  Future<void> enable() async => enabled = true;

  @override
  Future<void> waitForPendingWrites() async {}
}
