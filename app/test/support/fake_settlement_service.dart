import 'dart:async';

import 'package:roamio/features/splits/data/settlement_service.dart';

/// In-memory [SettlementService] for adventure ids; [recorded] and
/// [undone] list the writes.
class FakeSettlementService implements SettlementService {
  new([List<SettlementEntry> initial = const []]) : _live = [...initial];

  final List<SettlementEntry> _live;
  final List<SettlementEntry> recorded = [];
  final List<String> undone = [];
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<SettlementEntry>> settlements(String adventureId) async* {
    yield [..._live];
    yield* _changes.stream.map((_) => [..._live]);
  }

  @override
  Future<void> record(
    String adventureId, {
    required String from,
    required String to,
    required int amountMinor,
    required String currency,
    required String date,
    required int earlier,
  }) async {
    final s = SettlementEntry(
      id: settlementId(
        from: from,
        to: to,
        amountMinor: amountMinor,
        earlier: earlier,
      ),
      from: from,
      to: to,
      amountMinor: amountMinor,
      currency: currency,
      date: date,
      recordedBy: 'me',
    );
    recorded.add(s);
    // The same id is the same record, as in Firestore.
    _live
      ..removeWhere((e) => e.id == s.id)
      ..insert(0, s);
    _changes.add(null);
  }

  @override
  Future<void> undo(String adventureId, String settlementId) async {
    undone.add(settlementId);
    _live.removeWhere((s) => s.id == settlementId);
    _changes.add(null);
  }
}
