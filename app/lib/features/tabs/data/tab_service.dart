import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/split_engine.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/domain/new_tab.dart';

/// A saved tab as the adventure's tab list shows it.
class TabEntry {
  const new({
    required this.id,
    required this.description,
    required this.category,
    required this.date,
    required this.createdBy,
    required this.split,
    this.memories = const [],
    this.location,
  });

  final String id;
  final String description;
  final String category;
  final DateTime date;
  final String createdBy;
  final TabSplit split;

  /// Download links of up to 4 photos (spec UC-21).
  final List<String> memories;
  final MapPoint? location;

  Money get amount => split.amount;

  /// What [id] owes for this tab, in its currency; zero if not sharing.
  Money shareOf(String id) => Money(
    problemsWith(split).isEmpty ? sharesFor(split)[id] ?? 0 : 0,
    amount.currency,
  );
}

abstract interface class TabService {
  /// The adventure's tabs that aren't deleted, newest first.
  Stream<List<TabEntry>> tabs(String adventureId);

  /// Saves a tab as the signed-in member and returns its id at once.
  /// Works offline and syncs later.
  Future<String> addTab(String adventureId, NewTab tab);
}

/// Overridden in `main.dart` with the Firebase implementation.
final tabServiceProvider = Provider<TabService>(
  (ref) => throw UnimplementedError('tabServiceProvider must be overridden'),
);

final StreamProviderFamily<List<TabEntry>, String> tabsProvider =
    StreamProvider.family<List<TabEntry>, String>(
      (ref, adventureId) => ref.watch(tabServiceProvider).tabs(adventureId),
    );
