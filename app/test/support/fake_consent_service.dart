import 'dart:async';

import 'package:roamio/features/consent/data/consent_service.dart';

/// In-memory [ConsentService] for widget tests.
class FakeConsentService implements ConsentService {
  final List<String> calls = [];
  final _request = StreamController<MyConsentRequest?>.broadcast();
  MyConsentRequest? request;
  List<LinkedChild> children = const [];

  /// When set, the next action throws this message.
  String? failNext;

  /// What [describe] returns; null makes it throw [describeError].
  ConsentDetails? details = const ConsentDetails(
    childFirstName: 'Mia',
    relationship: 'mother',
    parentEmail: 'pat@example.com',
  );
  String describeError = 'This request has expired.';

  void setRequest(MyConsentRequest? value) {
    request = value;
    _request.add(value);
  }

  Future<void> _act(String call) async {
    calls.add(call);
    final failure = failNext;
    failNext = null;
    if (failure != null) throw ConsentException(failure);
  }

  @override
  Stream<MyConsentRequest?> myRequest() async* {
    yield request;
    yield* _request.stream;
  }

  @override
  Future<void> requestConsent({
    required String parentEmail,
    required String relationship,
  }) async {
    await _act('request:$parentEmail:$relationship');
    setRequest(MyConsentRequest(parentEmail: parentEmail, status: 'requested'));
  }

  @override
  Future<ConsentDetails> describe({
    required String childUid,
    required String token,
  }) async {
    calls.add('describe:$childUid:$token');
    return details ?? (throw ConsentException(describeError));
  }

  @override
  Future<void> decide({
    required String childUid,
    required String token,
    required bool grant,
  }) => _act('${grant ? 'grant' : 'decline'}:$childUid');

  @override
  Stream<List<LinkedChild>> linkedChildren() async* {
    yield children;
  }

  @override
  Future<void> withdraw(String childUid) => _act('withdraw:$childUid');

  @override
  Future<void> acceptAdultNotice() => _act('acceptAdult');
}
