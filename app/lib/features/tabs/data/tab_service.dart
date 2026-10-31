import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/split_engine.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/domain/new_tab.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

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
    this.deleted = false,
    this.updatedAt,
    this.status = TabStatus.approved,
    this.rejectReason,
  });

  /// Why an admin rejected it, if they said (spec UC-21a).
  final String? rejectReason;

  final String id;
  final String description;
  final String category;
  final DateTime date;
  final String createdBy;
  final TabSplit split;

  /// Download links of up to 4 photos (spec UC-21).
  final List<String> memories;
  final MapPoint? location;

  /// Whether it counts yet (spec UC-21a).
  final TabStatus status;

  /// Soft-deleted by a lead; kept for history (spec UC-22).
  final bool deleted;

  /// When the server last saved this tab; null while a change of yours is
  /// still waiting to sync, since the server hasn't stamped it yet.
  final DateTime? updatedAt;

  Money get amount => split.amount;

  /// What [id] owes for this tab, in its currency; zero if not sharing.
  Money shareOf(String id) => Money(
    problemsWith(split).isEmpty ? sharesFor(split)[id] ?? 0 : 0,
    amount.currency,
  );
}

/// Another admin decided first, or the signed-in person no longer can.
class TabAlreadyDecided implements Exception;

abstract interface class TabService {
  /// The adventure's tabs that aren't deleted and this person may see, newest
  /// first. [isAdmin] adds other people's rejected tabs.
  Stream<List<TabEntry>> tabs(String adventureId, {required bool isAdmin});

  /// Saves a tab as the signed-in member and returns its id at once.
  /// Works offline and syncs later.
  Future<String> addTab(String adventureId, NewTab tab);

  /// One tab, deleted or not; null if it doesn't exist.
  Stream<TabEntry?> tab(String adventureId, String tabId);

  /// The creator saves changes (spec UC-22). Photos already on the tab stay.
  Future<void> updateTab(String adventureId, String tabId, NewTab tab);

  /// A lead hides a tab; it stays in history (spec UC-22).
  Future<void> deleteTab(String adventureId, String tabId);

  /// An admin approves or rejects a waiting tab (spec UC-21a). Needs a
  /// connection. Throws [TabAlreadyDecided] if it can no longer be decided.
  Future<void> decideTab(
    String adventureId,
    String tabId, {
    required bool approve,
    String? reason,
  });
}

/// Overridden in `main.dart` with the Firebase implementation.
final tabServiceProvider = Provider<TabService>(
  (ref) => throw UnimplementedError('tabServiceProvider must be overridden'),
);

final StreamProviderFamily<TabEntry?, (String, String)> tabProvider =
    StreamProvider.family<TabEntry?, (String, String)>(
      (ref, ids) => ref.watch(tabServiceProvider).tab(ids.$1, ids.$2),
    );

final StreamProviderFamily<List<TabEntry>, String> tabsProvider =
    StreamProvider.family<List<TabEntry>, String>((ref, adventureId) {
      final uid = ref.watch(sessionFactsProvider).value?.uid;
      final isAdmin = ref.watch(
        myAdventuresProvider.select(
          (all) =>
              uid != null &&
              (all.value?.any((a) => a.id == adventureId && a.isLead(uid)) ??
                  false),
        ),
      );
      return ref.watch(tabServiceProvider).tabs(adventureId, isAdmin: isAdmin);
    });
