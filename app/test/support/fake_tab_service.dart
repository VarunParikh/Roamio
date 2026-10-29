import 'dart:async';

import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/new_tab.dart';

/// In-memory [TabService]. [added] and [updates] record writes; tabs given
/// to the constructor (adventure `bkk`) and added ones show in the lists.
class FakeTabService implements TabService {
  new([List<TabEntry> initial = const []]) {
    _byAdventure['bkk'] = [...initial];
  }

  final List<(String, NewTab)> added = [];
  final List<(String, String, NewTab)> updates = [];
  final List<String> deletes = [];
  final Map<String, List<TabEntry>> _byAdventure = {};
  final _changes = StreamController<void>.broadcast();

  List<TabEntry> _all(String adventureId) =>
      _byAdventure.putIfAbsent(adventureId, () => []);

  static TabEntry _entry(
    String id,
    NewTab t, {
    String? createdBy,
    List<String> memories = const [],
    bool deleted = false,
  }) => TabEntry(
    id: id,
    description: t.description.trim(),
    category: t.category,
    date: t.date,
    createdBy: createdBy ?? t.payers.first.payer,
    split: t.split,
    location: t.location,
    memories: memories,
    deleted: deleted,
  );

  List<TabEntry> _visible(String adventureId) => [
    for (final t in _all(adventureId))
      if (!t.deleted) t,
  ]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Stream<List<TabEntry>> tabs(String adventureId) async* {
    yield _visible(adventureId);
    yield* _changes.stream.map((_) => _visible(adventureId));
  }

  TabEntry? _find(String adventureId, String tabId) =>
      _all(adventureId).where((t) => t.id == tabId).firstOrNull;

  @override
  Stream<TabEntry?> tab(String adventureId, String tabId) async* {
    yield _find(adventureId, tabId);
    yield* _changes.stream.map((_) => _find(adventureId, tabId));
  }

  @override
  Future<String> addTab(String adventureId, NewTab tab) async {
    final id = 'tab${added.length}';
    added.add((adventureId, tab));
    _all(adventureId).add(_entry(id, tab));
    _changes.add(null);
    return id;
  }

  @override
  Future<void> updateTab(String adventureId, String tabId, NewTab tab) async {
    updates.add((adventureId, tabId, tab));
    final list = _all(adventureId);
    final i = list.indexWhere((t) => t.id == tabId);
    final old = list[i];
    list[i] = _entry(
      tabId,
      tab,
      createdBy: old.createdBy,
      memories: old.memories,
    );
    _changes.add(null);
  }

  @override
  Future<void> deleteTab(String adventureId, String tabId) async {
    deletes.add(tabId);
    final list = _all(adventureId);
    final i = list.indexWhere((t) => t.id == tabId);
    final old = list[i];
    list[i] = TabEntry(
      id: old.id,
      description: old.description,
      category: old.category,
      date: old.date,
      createdBy: old.createdBy,
      split: old.split,
      memories: old.memories,
      location: old.location,
      deleted: true,
    );
    _changes.add(null);
  }
}
