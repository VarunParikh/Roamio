import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/features/consent/data/firebase_consent_service.dart'
    show FirebaseConsentService;

/// The teen's own consent request, as they see it (spec §7.1).
class MyConsentRequest {
  const new({required this.parentEmail, required this.status});

  final String parentEmail;

  /// `requested`, `granted`, `declined`, `expired`, `withdrawn` or `closed`.
  final String status;
}

/// What a parent sees before deciding.
class ConsentDetails {
  const new({
    required this.childFirstName,
    required this.relationship,
    required this.parentEmail,
  });

  final String childFirstName;
  final String relationship;
  final String parentEmail;
}

/// A child this parent has given consent for (spec §7.3).
class LinkedChild {
  const new({required this.uid, required this.name, required this.since});

  final String uid;
  final String name;
  final DateTime? since;
}

/// A consent action failed; [message] is safe to show as-is.
class ConsentException implements Exception {
  new(this.message);

  final String message;

  @override
  String toString() => 'ConsentException($message)';
}

abstract interface class ConsentService {
  /// The signed-in teen's request, or null before they've sent one.
  Stream<MyConsentRequest?> myRequest();

  Future<void> requestConsent({
    required String parentEmail,
    required String relationship,
  });

  Future<ConsentDetails> describe({
    required String childUid,
    required String token,
  });

  Future<void> decide({
    required String childUid,
    required String token,
    required bool grant,
  });

  /// Children the signed-in parent currently consents for.
  Stream<List<LinkedChild>> linkedChildren();

  Future<void> withdraw(String childUid);

  /// A newly-18 account accepts the adult privacy notice (spec §7.4).
  Future<void> acceptAdultNotice();
}

/// Overridden in `main.dart` with [FirebaseConsentService].
final consentServiceProvider = Provider<ConsentService>(
  (ref) =>
      throw UnimplementedError('consentServiceProvider must be overridden'),
);
