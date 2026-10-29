import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_squad_service.dart';
import '../../support/fake_tab_service.dart';

/// Happening now (today is 29 Oct 2026): Ari leads, Bob is a member, Kiko
/// is a pal.
final _bangkok = Adventure(
  id: 'bkk',
  name: 'Bangkok trip',
  countryCode: 'TH',
  startDate: DateTime(2026, 10, 10),
  endDate: DateTime(2026, 11, 2),
  baseCurrency: 'THB',
  leaderUid: 'ari',
  memberUids: const ['ari', 'bob'],
);

TabEntry _tab(
  String id,
  String description,
  DateTime date, {
  required String paidBy,
  required int amount,
  required List<String> sharing,
  Map<String, int>? percentBp,
  MapPoint? location,
  List<String> memories = const [],
  bool deleted = false,
  DateTime? updatedAt,
}) => TabEntry(
  id: id,
  description: description,
  category: 'food_dining',
  date: date,
  createdBy: paidBy,
  location: location,
  memories: memories,
  deleted: deleted,
  updatedAt: updatedAt,
  split: TabSplit(
    amount: Money(amount, 'THB'),
    payers: [Payment(paidBy, amount)],
    participants: sharing,
    percentBp: percentBp,
    fxDate: '2026-10-29',
  ),
);

final _dinnerSavedAt = DateTime.utc(2026, 10, 29, 9);

List<TabEntry> _tabs() => [
  _tab(
    't1',
    'Dinner',
    DateTime(2026, 10, 29),
    paidBy: 'bob',
    amount: 90000,
    sharing: const ['ari', 'bob', 'kiko'],
    updatedAt: _dinnerSavedAt,
  ),
  _tab(
    't2',
    'Tuk-tuk',
    DateTime(2026, 10, 28),
    paidBy: 'ari',
    amount: 20000,
    sharing: const ['ari', 'bob'],
    percentBp: const {'ari': 7500, 'bob': 2500},
    location: const MapPoint(13.75, 100.5),
    memories: const ['https://files.example/1.webp'],
  ),
  _tab(
    't3',
    'Museum',
    DateTime(2026, 10, 20),
    paidBy: 'bob',
    amount: 5000,
    sharing: const ['bob'],
  ),
  _tab(
    't4',
    'Old taxi',
    DateTime(2026, 10, 19),
    paidBy: 'bob',
    amount: 1000,
    sharing: const ['bob'],
    deleted: true,
  ),
];

class _H {
  late FakeTabService tabs;
  final opened = <Uri>[];
}

Future<_H> _open(
  WidgetTester tester, {
  String as = 'ari',
  List<TabEntry>? tabs,
}) async {
  final h = _H()..tabs = FakeTabService(tabs ?? _tabs());
  await pumpRoamio(
    tester,
    FakeAuthService(
      initial: SessionFacts(uid: as, hasAccount: true, ageStatus: 'adult'),
    ),
    adventures: FakeAdventureService([_bangkok]),
    squad: FakeSquadService()
      ..names.addAll({'ari': 'Ari Chen', 'bob': 'Bob Lee'})
      ..palsByAdventure['bkk'] = [const Pal(id: 'kiko', nickname: 'Kiko')],
    tabs: h.tabs,
    openedLinks: h.opened,
  );
  await tester.tap(find.text('Bangkok trip').first);
  await tester.pumpAndSettle();
  return h;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('adventure page (UC-23)', () {
    testWidgets('tabs are grouped by day, newest first, with your share', (
      tester,
    ) async {
      await _open(tester);

      for (final day in ['Today', 'Yesterday', 'Tue, 20 Oct 2026']) {
        expect(find.text(day), findsOneWidget, reason: day);
      }
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('Bob Lee paid · Total ฿900.00'), findsOneWidget);
      expect(find.text('฿300.00'), findsOneWidget); // Ari's share
      expect(find.text('You paid · Total ฿200.00'), findsOneWidget);
      expect(find.text('฿150.00'), findsOneWidget); // 75% of ฿200
      expect(find.text('Not in it'), findsOneWidget); // the museum
      // Deleted tabs are not listed.
      expect(find.text('Old taxi'), findsNothing);
      expect(find.text('Add tab'), findsOneWidget);
    });

    testWidgets('with no tabs it says how to start', (tester) async {
      await _open(tester, tabs: const []);
      expect(find.text('No tabs yet. Add the first one.'), findsOneWidget);
      expect(find.text('Add tab'), findsOneWidget);
    });
  });

  group('tab details (UC-23)', () {
    testWidgets('shows who paid and everyone’s share', (tester) async {
      await _open(tester);
      await _tap(tester, find.text('Dinner'));

      // The total, and Bob's payment.
      expect(find.text('฿900.00'), findsNWidgets(2));
      expect(find.text('Paid by'), findsOneWidget);
      expect(find.text('Shares · split equally'), findsOneWidget);
      for (final who in ['Ari Chen (you)', 'Kiko']) {
        expect(find.text(who), findsOneWidget, reason: who);
      }
      expect(find.text('฿300.00'), findsNWidgets(3));
    });

    testWidgets('custom shares show their percentages; maps open', (
      tester,
    ) async {
      final h = await _open(tester);
      await _tap(tester, find.text('Tuk-tuk'));

      expect(find.text('Shares · custom %'), findsOneWidget);
      expect(find.text('75% · ฿150.00'), findsOneWidget);
      expect(find.text('25% · ฿50.00'), findsOneWidget);
      expect(find.byKey(const ValueKey('memory-0')), findsOneWidget);

      await _tap(tester, find.text('Open in Maps'));
      expect(h.opened.single.toString(), contains('query=13.75%2C100.5'));
    });

    testWidgets('a lead deletes someone else’s tab after confirming', (
      tester,
    ) async {
      final h = await _open(tester);
      await _tap(tester, find.text('Dinner'));

      expect(find.byTooltip('Edit tab'), findsNothing); // Bob created it
      await _tap(tester, find.byTooltip('Delete tab'));
      expect(find.text('Delete “Dinner”?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(h.tabs.deletes, ['t1']);
      expect(find.text('Dinner'), findsNothing);
      expect(find.text('Tuk-tuk'), findsOneWidget); // back on the page
    });

    testWidgets('the creator edits; members can’t delete', (tester) async {
      final h = await _open(tester, as: 'bob');
      await _tap(tester, find.text('Dinner'));

      expect(find.byTooltip('Delete tab'), findsNothing);
      await _tap(tester, find.byTooltip('Edit tab'));
      expect(find.text('Edit tab'), findsOneWidget);
      final amount = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Amount'),
      );
      expect(amount.controller!.text, '900.00');

      await tester.enterText(
        find.widgetWithText(TextField, 'Description (optional)'),
        'Dinner at Jay Fai',
      );
      await _tap(tester, find.text('Save changes'));

      final (aid, tid, tab) = h.tabs.updates.single;
      expect((aid, tid), ('bkk', 't1'));
      expect(tab.description, 'Dinner at Jay Fai');
      expect(tab.amountMinor, 90000);
      expect(tab.participants, ['ari', 'bob', 'kiko']);
      expect(tab.payers.single.payer, 'bob');
      // so the server can tell if this edit replaced a newer one (UC-32)
      expect(tab.basedOn, _dinnerSavedAt);
      expect(find.text('Dinner at Jay Fai'), findsWidgets);
    });

    testWidgets('a deleted tab says so', (tester) async {
      await _open(tester);
      unawaited(
        GoRouter.of(tester.element(find.text('Dinner')))
            .push('/adventures/bkk/tabs/t4'),
      );
      await tester.pumpAndSettle();
      expect(find.text('This tab was deleted.'), findsOneWidget);
      expect(find.byTooltip('Delete tab'), findsNothing);
    });
  });
}
