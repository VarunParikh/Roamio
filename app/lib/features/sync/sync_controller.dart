import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/connectivity/connectivity_monitor.dart';

/// Where the app stands with the squad's data (spec UC-30–UC-31).
enum SyncPhase {
  /// Connected; changes go straight up.
  online,

  /// No connection. Changes are kept on the phone.
  offline,

  /// Connection is back; waiting for the person to press Sync.
  needsSync,

  syncing,
  synced,
  failed,
}

@immutable
class SyncState {
  const new(this.phase, {this.error});

  final SyncPhase phase;

  /// What went wrong, when [phase] is [SyncPhase.failed].
  final String? error;

  /// Joining, inviting, role changes and deleting an account need a
  /// connection (UC-33).
  bool get isOffline => phase != SyncPhase.online && phase != SyncPhase.synced;
}

/// Turns Firestore's network off and on, and waits for queued writes.
abstract interface class NetworkSwitch {
  Future<void> disable();
  Future<void> enable();
  Future<void> waitForPendingWrites();
}

/// Overridden in `main.dart` with [FirestoreNetworkSwitch].
final networkSwitchProvider = Provider<NetworkSwitch>(
  (ref) => throw UnimplementedError('networkSwitchProvider must be overridden'),
);

/// Uploads photos that are waiting. Overridden in `main.dart`.
final photoFlushProvider = Provider<Future<void> Function()>(
  (ref) => throw UnimplementedError('photoFlushProvider must be overridden'),
);

class FirestoreNetworkSwitch implements NetworkSwitch {
  new(this._db);

  final FirebaseFirestore _db;

  @override
  Future<void> disable() => _db.disableNetwork();

  @override
  Future<void> enable() => _db.enableNetwork();

  @override
  Future<void> waitForPendingWrites() => _db.waitForPendingWrites();
}

/// True while changes are being kept on the phone (UC-33): joining,
/// inviting, role changes and deleting an account switch off.
final isOfflineProvider = Provider<bool>(
  (ref) => ref.watch(syncControllerProvider.select((s) => s.isOffline)),
);

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

/// Goes offline when the connection drops, offers Sync when it returns, and
/// on Sync re-enables the network and sends everything that was waiting.
class SyncController extends Notifier<SyncState> {
  Future<void>? _syncing;

  /// Completes once the starting connection has been checked.
  late final Future<void> ready;

  @override
  SyncState build() {
    final monitor = ref.watch(connectivityMonitorProvider);
    final subscription = monitor.changes.listen(
      (online) => unawaited(_onConnectivity(online)),
    );
    ref.onDispose(subscription.cancel);
    ready = monitor.check().then(_onStart);
    return const SyncState(SyncPhase.online);
  }

  Future<void> _onStart(bool online) async {
    if (!online) await _goOffline();
  }

  Future<void> _onConnectivity(bool online) async {
    if (_syncing != null) return; // sync() settles its own outcome
    if (!online) {
      if (state.phase != SyncPhase.offline) await _goOffline();
    } else if (state.phase == SyncPhase.offline) {
      state = const SyncState(SyncPhase.needsSync);
    }
  }

  Future<void> _goOffline() async {
    await ref.read(networkSwitchProvider).disable();
    state = const SyncState(SyncPhase.offline);
  }

  /// Re-enables the network and uploads queued tabs, settlements and photos.
  Future<void> sync() =>
      _syncing ??= _runSync().whenComplete(() => _syncing = null);

  Future<void> _runSync() async {
    final network = ref.read(networkSwitchProvider);
    state = const SyncState(SyncPhase.syncing);
    try {
      await network.enable();
      await network.waitForPendingWrites();
      await ref.read(photoFlushProvider)();
      state = const SyncState(SyncPhase.synced);
    } on Object catch (error) {
      if (await ref.read(connectivityMonitorProvider).check()) {
        state = SyncState(SyncPhase.failed, error: '$error');
      } else {
        await _goOffline();
      }
    }
  }

  /// Hides the "Synced ✓" message.
  void dismissSynced() {
    if (state.phase == SyncPhase.synced) {
      state = const SyncState(SyncPhase.online);
    }
  }
}
