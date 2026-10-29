import 'dart:async';

import 'package:roamio/features/notifications/data/notification_service.dart';

/// In-memory [NotificationService]; [allow] is what Android's prompt answers.
class FakeNotificationService implements NotificationService {
  new({this.answer, this.allow = true});

  bool? answer;
  bool allow;
  final List<String> calls = [];
  final _changes = StreamController<bool?>.broadcast();

  @override
  Stream<bool?> consent() async* {
    yield answer;
    yield* _changes.stream;
  }

  @override
  Future<bool> turnOn() async {
    calls.add('turnOn');
    answer = allow;
    _changes.add(answer);
    return allow;
  }

  @override
  Future<void> decline() async {
    calls.add('decline');
    answer = false;
    _changes.add(false);
  }

  @override
  Future<void> refresh() async => calls.add('refresh');
}
