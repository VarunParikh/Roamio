import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// An adventure's current invite link (spec UC-9).
class SharedInvite {
  const new({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

/// What someone sees about an invite before joining (UC-12, UC-13).
class InviteDetails {
  const new({
    required this.code,
    required this.adventureId,
    required this.adventureName,
    required this.leaderName,
    required this.countryCode,
    required this.startDate,
    required this.endDate,
    this.leaderUid = '',
    this.leaderCharacterId,
  });

  final String code;
  final String adventureId;
  final String adventureName;
  final String leaderName;
  final String leaderUid;
  final String? leaderCharacterId;
  final String countryCode;
  final DateTime startDate;
  final DateTime endDate;
}

/// An invite action failed; [message] is safe to show as-is.
class InviteException implements Exception {
  new(this.message);

  final String message;

  @override
  String toString() => 'InviteException($message)';
}

abstract interface class InviteService {
  /// The current code for an adventure the caller leads, making one if needed.
  Future<SharedInvite> createInvite(String adventureId);

  /// Stops the current link working.
  Future<void> revokeInvite(String adventureId);

  Future<InviteDetails> lookup(String code);

  /// Joins the invite's squad as a Member and drops it from Invites;
  /// returns the adventure's id (spec UC-13).
  Future<String> join(String code);

  /// Codes the signed-in person has opened but not yet acted on.
  Stream<List<String>> savedCodes();

  Future<void> saveCode(String code);

  Future<void> forgetCode(String code);
}

/// Overridden in `main.dart` with the Firebase implementation.
final inviteServiceProvider = Provider<InviteService>(
  (ref) => throw UnimplementedError('inviteServiceProvider must be overridden'),
);

final savedInviteCodesProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(inviteServiceProvider).savedCodes(),
);

final FutureProviderFamily<InviteDetails, String> inviteDetailsProvider =
    FutureProvider.family<InviteDetails, String>(
      (ref, code) => ref.watch(inviteServiceProvider).lookup(code),
    );
