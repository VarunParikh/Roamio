import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/sync/sync_banner.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/tab_approval.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_sync.dart';
import '../../support/fake_tab_service.dart';

/// Ari leads, Cara is co-lead, Bob is a member.
final _team = Adventure(
  id: 'bkk',
  name: 'Bangkok trip',
  countryCode: 'TH',
  startDate: DateTime(2026, 10),
  endDate: DateTime(2026, 12, 8),
  baseCurrency: 'THB',
  leaderUid: 'ari',
  coLeadUids: const ['cara'],
  memberUids: const ['ari', 'cara', 'bob'],
);

/// Ari is the only admin.
final _solo = Adventure(
  id: 'bkk',
  name: 'Bangkok trip',
  countryCode: 'TH',
  startDate: DateTime(2026, 10),
  endDate: DateTime(2026, 12, 8),
  baseCurrency: 'THB',
  leaderUid: 'ari',
  memberUids: const ['ari', 'bob'],
);

TabEntry _tab({
  String by = 'bob',
  TabStatus status = TabStatus.waiting,
  String id = 't1',
}) => TabEntry(
  id: id,
  description: 'Dinner',
  category: 'food_dining',
  date: DateTime(2026, 10, 20),
  createdBy: by,
  status: status,
  split: TabSplit(
    amount: Money(30000, 'THB'),
    payers: [Payment(by, 30000)],
    participants: const ['ari', 'bob'],
    fxDate: '2026-10-20',
  ),
);

Future<FakeTabService> _open(
  WidgetTester tester, {
  required String as,
  Adventure? adventure,
  List<TabEntry>? tabs,
  bool online = true,
  bool past = false,
}) async {
  final service = FakeTabService(tabs ?? [_tab()]);
  await pumpRoamio(
    tester,
    FakeAuthService(
      initial: SessionFacts(uid: as, hasAccount: true, ageStatus: 'adult'),
    ),
    adventures: FakeAdventureService([adventure ?? _team]),
    tabs: service,
    connectivity: FakeConnectivity(online: online),
  );
  if (past) {
    await tester.tap(find.text('Past adventures (1)'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Bangkok trip'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Dinner'),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
  return service;
}

Finder _button(String label) => find.widgetWithText(OutlinedButton, label);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('who starts how (spec UC-21a)', () {
    test('a member’s tab waits', () {
      expect(statusForNewTab(_team, 'bob'), TabStatus.waiting);
      expect(statusForNewTab(_solo, 'bob'), TabStatus.waiting);
    });

    test('an admin’s tab waits for the other admin', () {
      expect(statusForNewTab(_team, 'ari'), TabStatus.waiting);
      expect(statusForNewTab(_team, 'cara'), TabStatus.waiting);
    });

    test('the only admin’s own tab is approved', () {
      expect(statusForNewTab(_solo, 'ari'), TabStatus.approved);
    });
  });

  group('who can decide (spec UC-21a)', () {
    test('admins can, members can’t', () {
      expect(canDecideTab(_team, _tab(), 'ari'), isTrue);
      expect(canDecideTab(_team, _tab(), 'cara'), isTrue);
      expect(canDecideTab(_team, _tab(), 'bob'), isFalse);
    });

    test('not your own while another admin exists', () {
      expect(canDecideTab(_team, _tab(by: 'ari'), 'ari'), isFalse);
      expect(canDecideTab(_team, _tab(by: 'ari'), 'cara'), isTrue);
    });

    test('the only admin can decide their own', () {
      expect(canDecideTab(_solo, _tab(by: 'ari'), 'ari'), isTrue);
    });

    test('only while it’s waiting', () {
      for (final s in [
        TabStatus.approved,
        TabStatus.rejected,
        TabStatus.personal,
      ]) {
        expect(canDecideTab(_team, _tab(status: s), 'ari'), isFalse);
      }
    });
  });

  group('on the tab list', () {
    testWidgets('an admin approves from the row', (tester) async {
      final tabs = await _open(tester, as: 'ari');

      expect(find.text(waitingLabel), findsOneWidget);
      await _tap(tester, _button('Approve'));

      expect(tabs.decisions, ['t1 approved']);
      expect(find.text(waitingLabel), findsNothing);
      expect(_button('Approve'), findsNothing);
    });

    testWidgets('Reject asks first; Cancel changes nothing', (tester) async {
      final tabs = await _open(tester, as: 'cara');

      await _tap(tester, _button('Reject'));
      expect(find.text('Reject this tab?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tabs.decisions, isEmpty);
      expect(_button('Approve'), findsOneWidget);

      await _tap(tester, _button('Reject'));
      await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
      await tester.pumpAndSettle();
      expect(tabs.decisions, ['t1 rejected']);
    });

    testWidgets('a member sees it’s waiting, with no buttons', (tester) async {
      await _open(tester, as: 'bob');

      expect(find.text(waitingLabel), findsOneWidget);
      expect(_button('Approve'), findsNothing);
      expect(_button('Reject'), findsNothing);
    });

    testWidgets('an admin gets no buttons on their own tab', (tester) async {
      await _open(
        tester,
        as: 'ari',
        tabs: [_tab(by: 'ari')],
      );

      expect(find.text(waitingLabel), findsOneWidget);
      expect(_button('Approve'), findsNothing);
    });

    testWidgets('an approved tab has no label or buttons', (tester) async {
      await _open(
        tester,
        as: 'ari',
        tabs: [_tab(status: TabStatus.approved)],
      );

      expect(find.text(waitingLabel), findsNothing);
      expect(_button('Approve'), findsNothing);
    });

    testWidgets('offline, the buttons are off and say why', (tester) async {
      final tabs = await _open(tester, as: 'ari', online: false);

      expect(
        tester.widget<OutlinedButton>(_button('Approve')).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(_button('Reject')).onPressed,
        isNull,
      );
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Dinner'),
            matching: find.byType(Card),
          ),
          matching: find.text(needsConnectionNote),
        ),
        findsOneWidget,
      );
      expect(tabs.decisions, isEmpty);
    });

    testWidgets('someone else got there first: says so', (tester) async {
      final tabs = await _open(tester, as: 'ari');
      tabs.alreadyDecided = true;

      await _tap(tester, _button('Approve'));

      expect(find.text(alreadyDecidedMessage), findsOneWidget);
    });

    testWidgets('still decidable after the window for adding tabs', (
      tester,
    ) async {
      final ended = Adventure(
        id: 'bkk',
        name: 'Bangkok trip',
        countryCode: 'TH',
        startDate: DateTime(2020),
        endDate: DateTime(2020, 1, 8),
        baseCurrency: 'THB',
        leaderUid: 'ari',
        coLeadUids: const ['cara'],
        memberUids: const ['ari', 'cara', 'bob'],
      );
      await _open(tester, as: 'ari', adventure: ended, past: true);

      expect(
        tester.widget<OutlinedButton>(_button('Approve')).onPressed,
        isNotNull,
      );
    });
  });
}
