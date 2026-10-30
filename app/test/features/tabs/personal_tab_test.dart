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
    TabStatus edit(
      Adventure a,
      String uid,
      TabStatus before, {
      List<String> sharing = const ['bob', 'cara'],
      int amountMinor = 100,
      String currency = 'THB',
      List<Payment>? payers,
      Map<String, int>? percentBp,
    }) => statusForEditedTab(
      a,
      uid,
      TabEntry(
        id: 't',
        description: '',
        category: 'food_dining',
        date: DateTime(2026, 10, 20),
        createdBy: uid,
        status: before,
        split: TabSplit(
          amount: Money(100, 'THB'),
          payers: [Payment(uid, 100)],
          participants: const ['bob', 'cara'],
          fxDate: '2026-10-20',
        ),
      ),
      amountMinor: amountMinor,
      currency: currency,
      payers: payers ?? [Payment(uid, amountMinor)],
      sharing: sharing,
      percentBp: percentBp,
    );

    test('adding someone to a personal tab makes it wait', () {
      expect(edit(_team, 'bob', TabStatus.personal), TabStatus.waiting);
    });

    test('for the only admin it’s approved', () {
      expect(
        edit(_solo, 'ari', TabStatus.personal, sharing: const ['ari', 'bob']),
        TabStatus.approved,
      );
    });

    test('a shared tab left with only you becomes personal', () {
      expect(
        edit(_team, 'bob', TabStatus.approved, sharing: const ['bob']),
        TabStatus.personal,
      );
    });

    test('resubmitting a rejected tab makes it wait', () {
      expect(edit(_team, 'bob', TabStatus.rejected), TabStatus.waiting);
    });

    test('a money edit to an approved tab makes it wait', () {
      expect(
        edit(_team, 'bob', TabStatus.approved, amountMinor: 200),
        TabStatus.waiting,
      );
      expect(
        edit(_team, 'bob', TabStatus.approved, currency: 'INR'),
        TabStatus.waiting,
      );
      expect(
        edit(_team, 'bob', TabStatus.approved, sharing: const ['bob', 'mia']),
        TabStatus.waiting,
      );
      expect(
        edit(
          _team,
          'bob',
          TabStatus.approved,
          percentBp: const {'bob': 5000, 'cara': 5000},
        ),
        TabStatus.waiting,
      );
    });

    test('the same money stays approved', () {
      expect(edit(_team, 'bob', TabStatus.approved), TabStatus.approved);
    });

    test('the only admin’s money edit stays approved', () {
      expect(
        edit(_solo, 'ari', TabStatus.approved, amountMinor: 200),
        TabStatus.approved,
      );
    });

    test('a waiting tab keeps waiting', () {
      expect(
        edit(_team, 'bob', TabStatus.waiting, amountMinor: 200),
        TabStatus.waiting,
      );
    });
  });

  group('mergedTabs', () {
    final oct1 = DateTime(2026, 10);
    final oct2 = DateTime(2026, 10, 2);

    test('waits for both, then lists them newest first', () async {
      final shared = StreamController<List<TabEntry>>();
      final personal = StreamController<List<TabEntry>>();
      final out = <List<String>>[];
      final sub = mergedTabs([shared.stream, personal.stream])
          .listen((t) => out.add([for (final e in t) e.id]));

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

    test('a tab two queries both return appears once', () async {
      final a = _entry('same', oct1, status: TabStatus.rejected);
      final out = await mergedTabs([
        Stream.value([a]),
        Stream.value([a]),
      ]).first;
      expect(out.map((t) => t.id), ['same']);
    });

    test('passes an error on', () async {
      final shared = StreamController<List<TabEntry>>();
      final personal = StreamController<List<TabEntry>>();
      final errors = <Object>[];
      final sub = mergedTabs([shared.stream, personal.stream])
          .listen((_) {}, onError: errors.add);

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
