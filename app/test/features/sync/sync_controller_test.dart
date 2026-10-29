import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/connectivity/connectivity_monitor.dart';
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

  test('online at start: normal, network left alone', () async {
    await start(online: true);
    expect(phase(), SyncPhase.online);
    expect(network.calls, isEmpty);
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
    expect(network.calls, ['disable']);
  });

  test('coming back shows Sync but does not touch the network', () async {
    await start(online: false);
    connectivity.set(online: true);
    await pumpEventQueue();
    expect(phase(), SyncPhase.needsSync);
    expect(network.calls, ['disable']);
  });

  test('blips that never went offline do not ask for a sync', () async {
    await start(online: true);
    connectivity.set(online: true);
    await pumpEventQueue();
    expect(phase(), SyncPhase.online);
  });

  test('Sync re-enables the network, uploads writes and photos', () async {
    await start(online: false);
    connectivity.set(online: true);
    await pumpEventQueue();

    await container.read(syncControllerProvider.notifier).sync();

    expect(phase(), SyncPhase.synced);
    expect(network.calls, ['disable', 'enable', 'writes']);
    expect(photoRuns, ['photos']);
  });

  test('a failed sync shows the error and can be retried', () async {
    await start(online: false);
    connectivity.set(online: true);
    await pumpEventQueue();
    network.failWrites = Exception('permission-denied');

    final notifier = container.read(syncControllerProvider.notifier);
    await notifier.sync();

    final failed = container.read(syncControllerProvider);
    expect(failed.phase, SyncPhase.failed);
    expect(failed.error, isNotEmpty);

    await notifier.sync();
    expect(phase(), SyncPhase.synced);
  });

  test('dropping offline mid-sync ends offline, not failed', () async {
    await start(online: false);
    connectivity.set(online: true);
    await pumpEventQueue();
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
    final notifier = container.read(syncControllerProvider.notifier);
    await notifier.sync();

    notifier.dismissSynced();

    expect(phase(), SyncPhase.online);
  });

  test('a second tap while syncing does nothing', () async {
    await start(online: false);
    connectivity.set(online: true);
    await pumpEventQueue();
    final notifier = container.read(syncControllerProvider.notifier);

    await Future.wait([notifier.sync(), notifier.sync()]);

    expect(network.calls.where((c) => c == 'enable'), hasLength(1));
  });
}
