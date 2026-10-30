import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/data/merged_tabs.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/tab_approval.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_tab_service.dart';

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

const _bobPaid = [Payment('bob', 100)];

TabEntry _entry(
  String id,
  DateTime date, {
  TabStatus? status,
  String by = 'bob',
}) => TabEntry(
  id: id,
  description: id,
  category: 'food_dining',
  date: date,
  createdBy: by,
  status: status ?? TabStatus.personal,
  split: TabSplit(
    amount: Money(100, 'THB'),
    payers: [Payment(by, 100)],
    participants: [by],
    fxDate: '2026-10-20',
  ),
);

void main() {
  group('what makes a tab personal (spec UC-21a)', () {
    test('you paid and only you share', () {
      expect(isPersonalShape('bob', _bobPaid, const ['bob']), isTrue);
    });

    test('someone else sharing or paying makes it shared', () {
      expect(isPersonalShape('bob', _bobPaid, const ['bob', 'mia']), isFalse);
      expect(isPersonalShape('bob', _bobPaid, const ['mia']), isFalse);
      expect(
        isPersonalShape('bob', const [Payment('mia', 100)], const ['bob']),
        isFalse,
      );
      expect(
        isPersonalShape(
          'bob',
          const [Payment('bob', 50), Payment('mia', 50)],
          const ['bob'],
        ),
        isFalse,
      );
    });

    test('a new tab starts personal, for anyone', () {
      expect(
        statusForNewTab(_team, 'bob', _bobPaid, const ['bob']),
        TabStatus.personal,
      );
      expect(
        statusForNewTab(_solo, 'ari', const [Payment('ari', 1)], const ['ari']),
        TabStatus.personal,
      );
    });

    test('a shared new tab waits, or is approved for the only admin', () {
      expect(
        statusForNewTab(_team, 'bob', _bobPaid, const ['bob', 'ari']),
        TabStatus.waiting,
      );
      expect(
        statusForNewTab(
          _solo,
          'ari',
          const [Payment('ari', 1)],
          const ['ari', 'bob'],
        ),
        TabStatus.approved,
      );
    });
  });

  group('editing changes it (spec UC-21a)', () {
    test('adding someone to a personal tab makes it wait', () {
      expect(
        statusForEditedTab(_team, 'bob', TabStatus.personal, _bobPaid, const [
          'bob',
          'cara',
        ]),
        TabStatus.waiting,
      );
    });

    test('for the only admin it’s approved', () {
      expect(
        statusForEditedTab(
          _solo,
          'ari',
          TabStatus.personal,
          const [Payment('ari', 1)],
          const ['ari', 'bob'],
        ),
        TabStatus.approved,
      );
    });

    test('a shared tab left with only you becomes personal', () {
      expect(
        statusForEditedTab(_team, 'bob', TabStatus.approved, _bobPaid, const [
          'bob',
        ]),
        TabStatus.personal,
      );
    });

    test('otherwise an edit keeps the status', () {
      for (final s in [TabStatus.waiting, TabStatus.approved]) {
        expect(
          statusForEditedTab(_team, 'bob', s, _bobPaid, const ['bob', 'cara']),
          s,
        );
      }
    });
  });

  group('mergedTabs', () {
    final oct1 = DateTime(2026, 10);
    final oct2 = DateTime(2026, 10, 2);

    test('waits for both, then lists them newest first', () async {
      final shared = StreamController<List<TabEntry>>();
      final personal = StreamController<List<TabEntry>>();
      final out = <List<String>>[];
      final sub = mergedTabs(
        shared.stream,
        personal.stream,
      ).listen((t) => out.add([for (final e in t) e.id]));

      shared.add([_entry('old', oct1, status: TabStatus.approved)]);
      await pumpEventQueue();
      expect(out, isEmpty);

      personal.add([_entry('new', oct2)]);
      await pumpEventQueue();
      expect(out, [
        ['new', 'old'],
      ]);

      personal.add([]);
      await pumpEventQueue();
      expect(out.last, ['old']);
      await sub.cancel();
    });

    test('passes an error on', () async {
      final shared = StreamController<List<TabEntry>>();
      final personal = StreamController<List<TabEntry>>();
      final errors = <Object>[];
      final sub = mergedTabs(
        shared.stream,
        personal.stream,
      ).listen((_) {}, onError: errors.add);

      shared.addError('offline');
      await pumpEventQueue();
      expect(errors, ['offline']);
      await sub.cancel();
    });
  });

  group('on screen', () {
    Future<void> open(WidgetTester tester, {required String as}) async {
      await pumpRoamio(
        tester,
        FakeAuthService(
          initial: SessionFacts(uid: as, hasAccount: true, ageStatus: 'adult'),
        ),
        adventures: FakeAdventureService([_team]),
        tabs: FakeTabService([_entry('Sim card', DateTime(2026, 10, 20))]),
      );
      await tester.tap(find.text('Bangkok trip'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Sim card'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the row says it’s personal, with no buttons', (tester) async {
      await open(tester, as: 'bob');

      expect(find.text(personalLabel), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Approve'), findsNothing);
    });

    testWidgets('its creator can delete it', (tester) async {
      await open(tester, as: 'bob');

      await tester.tap(find.text('Sim card'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Delete tab'), findsOneWidget);
    });
  });
}
