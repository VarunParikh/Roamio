import 'dart:async';

import 'package:roamio/core/connectivity/connectivity_monitor.dart';
import 'package:roamio/features/sync/sync_controller.dart';

/// A phone whose connection the test switches on and off.
class FakeConnectivity implements ConnectivityMonitor {
  new({this.online = true});

  bool online;
  final _changes = StreamController<bool>.broadcast();

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Future<bool> check() async => online;

  /// The connection changes; the monitor reports it.
  void set({required bool online}) {
    this.online = online;
    _changes.add(online);
  }
}

/// Records Firestore's network switches and queued work.
class FakeNetworkSwitch implements NetworkSwitch {
  final List<String> calls = [];

  /// When set, the next [waitForPendingWrites] fails with this.
  Exception? failWrites;

  @override
  Future<void> disable() async => calls.add('disable');

  @override
  Future<void> enable() async => calls.add('enable');

  @override
  Future<void> waitForPendingWrites() async {
    calls.add('writes');
    if (failWrites case final error?) {
      failWrites = null;
      throw error;
    }
  }
}
