import 'dart:async';

import 'package:roamio/features/invites/data/invite_service.dart';

/// In-memory [InviteService]: [valid] codes resolve, others fail with
/// [unknownMessage]; [saved] mirrors the person's Invites list.
class FakeInviteService implements InviteService {
  new({Map<String, InviteDetails>? valid}) : valid = valid ?? {};

  final Map<String, InviteDetails> valid;
  final List<String> saved = [];
  final List<String> calls = [];
  final List<String> joined = [];

  /// When set, [join] fails with this message.
  String? joinError;
  final _savedChanges = StreamController<List<String>>.broadcast();
  String unknownMessage = 'We couldn’t find that invite. Check the code.';
  int _next = 0;
  String? current;

  @override
  Future<SharedInvite> createInvite(String adventureId) async {
    calls.add('create:$adventureId');
    current ??= 'ABCD${'EFGHJKMN'.substring(_next, _next + 4)}';
    return SharedInvite(code: current!, expiresAt: DateTime(2026, 11, 12));
  }

  @override
  Future<void> revokeInvite(String adventureId) async {
    calls.add('revoke:$adventureId');
    current = null;
    _next = (_next + 4) % 8;
  }

  @override
  Future<InviteDetails> lookup(String code) async {
    calls.add('lookup:$code');
    return valid[code] ?? (throw InviteException(unknownMessage));
  }

  @override
  Future<String> join(String code) async {
    final message = joinError;
    if (message != null) throw InviteException(message);
    joined.add(code);
    await forgetCode(code);
    return valid[code]!.adventureId;
  }

  @override
  Stream<List<String>> savedCodes() async* {
    yield [...saved];
    yield* _savedChanges.stream;
  }

  @override
  Future<void> saveCode(String code) async {
    if (!saved.contains(code)) saved.insert(0, code);
    _savedChanges.add([...saved]);
  }

  @override
  Future<void> forgetCode(String code) async {
    saved.remove(code);
    _savedChanges.add([...saved]);
  }
}
