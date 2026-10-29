import 'dart:async';

import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/new_tab.dart';

/// In-memory [TabService]: [added] records saved tabs, which then show in
/// the adventure's list.
class FakeTabService implements TabService {
  final List<(String, NewTab)> added = [];
  final _changes = StreamController<void>.broadcast();

  List<TabEntry> _entries(String adventureId) => [
    for (final (i, (aid, t)) in added.indexed)
      if (aid == adventureId)
        TabEntry(
          id: 'tab$i',
          description: t.description.trim(),
          category: t.category,
          date: t.date,
          createdBy: t.payers.first.payer,
          split: t.split,
          location: t.location,
        ),
  ].reversed.toList();

  @override
  Stream<List<TabEntry>> tabs(String adventureId) async* {
    yield _entries(adventureId);
    yield* _changes.stream.map((_) => _entries(adventureId));
  }

  @override
  Future<String> addTab(String adventureId, NewTab tab) async {
    added.add((adventureId, tab));
    _changes.add(null);
    return 'tab${added.length - 1}';
  }
}
