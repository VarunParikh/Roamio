import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Push notifications, on only with the person's say-so (spec §8: consent
/// per purpose). The answer is kept in their account's
/// `consents.notifications`; the server pushes only when it is true.
abstract interface class NotificationService {
  /// true or false once they've answered; null if never asked.
  Stream<bool?> consent();

  /// Asks Android for permission and, if given, registers this phone.
  /// Returns whether notifications are now on.
  Future<bool> turnOn();

  /// Records "not now", so the question isn't asked again.
  Future<void> decline();

  /// Re-registers this phone if notifications are on (tokens change).
  Future<void> refresh();
}

/// Overridden in `main.dart` with the Firebase implementation.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => throw UnimplementedError(
    'notificationServiceProvider must be overridden',
  ),
);

final notificationConsentProvider = StreamProvider<bool?>(
  (ref) => ref.watch(notificationServiceProvider).consent(),
);
