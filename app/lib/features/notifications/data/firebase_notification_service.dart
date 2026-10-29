import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:roamio/features/notifications/data/notification_service.dart';

class FirebaseNotificationService implements NotificationService {
  new(this._auth, this._db, this._messaging) {
    // Fires with this phone's installation ID after register(), and again
    // whenever it changes.
    _messaging.onRegistered.listen((id) => unawaited(_save(id)));
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseMessaging _messaging;

  DocumentReference<Map<String, dynamic>>? get _account {
    final uid = _auth.currentUser?.uid;
    return uid == null ? null : _db.doc('users/$uid/private/account');
  }

  @override
  Stream<bool?> consent() =>
      _account?.snapshots().map(
        (s) => (s.data()?['consents'] as Map?)?['notifications'] as bool?,
      ) ??
      Stream.value(null);

  @override
  Future<bool> turnOn() async {
    final settings = await _messaging.requestPermission();
    final on =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    await _account?.update({'consents.notifications': on});
    if (on) await refresh();
    return on;
  }

  @override
  Future<void> decline() async {
    await _account?.update({'consents.notifications': false});
  }

  @override
  Future<void> refresh() async {
    final account = await _account?.get();
    final on = (account?.data()?['consents'] as Map?)?['notifications'];
    if (on == true) await _messaging.register();
  }

  /// Stored in `fcmTokens` (DATA_MODEL.md): this phone's installation ID.
  Future<void> _save(String installationId) async {
    await _account?.update({
      'fcmTokens': FieldValue.arrayUnion([installationId]),
    });
  }
}
