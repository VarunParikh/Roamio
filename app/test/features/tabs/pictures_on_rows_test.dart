import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/squad/ui/person.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_squad_service.dart';
import '../../support/fake_tab_service.dart';

const _members = ['ari', 'bob', 'cara', 'dan', 'eve', 'fay'];

final _trip = Adventure(
  id: 'bkk',
  name: 'Bangkok trip',
  countryCode: 'TH',
  startDate: DateTime(2026, 10),
  endDate: DateTime(2026, 12, 8),
  baseCurrency: 'THB',
  leaderUid: 'ari',
  memberUids: _members,
);

TabEntry _tab(List<String> sharing, {TabStatus status = TabStatus.approved}) =>
    TabEntry(
      id: 't1',
      description: 'Dinner',
      category: 'food_dining',
      date: DateTime(2026, 10, 20),
      createdBy: 'bob',
      status: status,
      split: TabSplit(
        amount: Money(60000, 'THB'),
        payers: [Payment(sharing.first, 60000)],
        participants: sharing,
        fxDate: '2026-10-20',
      ),
    );

Future<void> _open(WidgetTester tester, TabEntry tab) async {
  final squad = FakeSquadService()
    ..names.addAll({'ari': 'Ari', 'bob': 'Bob', 'cara': 'Cara'})
    ..characters['bob'] = 'panda';
  await pumpRoamio(
    tester,
    FakeAuthService(
      initial: const SessionFacts(
        uid: 'cara',
        hasAccount: true,
        ageStatus: 'adult',
      ),
    ),
    adventures: FakeAdventureService([_trip]),
    tabs: FakeTabService([tab]),
    squad: squad,
  );
  await tester.tap(find.text('Bangkok trip'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Dinner'),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

Map<String, SquadPerson> get _people => const {
  'ari': SquadPerson(name: 'Ari'),
  'bob': SquadPerson(name: 'Bob'),
};

void main() {
  group('PeoplePictures', () {
    test('you come first, then the tab’s own order', () {
      expect(PeoplePictures.ordered(const ['a', 'b', 'me'], 'me'), [
        'me',
        'a',
        'b',
      ]);
      expect(PeoplePictures.ordered(const ['a', 'b'], 'me'), ['a', 'b']);
    });

    test('TalkBack wording', () {
      expect(PeoplePictures.sharedByLabel(const ['you']), 'Shared by you');
      expect(
        PeoplePictures.sharedByLabel(const ['you', 'Ari']),
        'Shared by you and Ari',
      );
      expect(
        PeoplePictures.sharedByLabel(const ['Ari', 'Cara', 'Bob']),
        'Shared by Ari, Cara and 1 other',
      );
      expect(
        PeoplePictures.sharedByLabel(const ['Ari', 'Cara', 'a', 'b', 'c']),
        'Shared by Ari, Cara and 3 others',
      );
    });

    testWidgets('shows up to 4, then +N', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeoplePictures(
              ids: _members,
              people: _people,
              firstUid: 'ari',
            ),
          ),
        ),
      );

      expect(find.byType(PersonAvatar), findsNWidgets(4));
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('no +N when everyone fits', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeoplePictures(
              ids: const ['ari', 'bob'],
              people: _people,
              firstUid: 'ari',
            ),
          ),
        ),
      );

      expect(find.byType(PersonAvatar), findsNWidgets(2));
      expect(find.textContaining('+'), findsNothing);
    });
  });

  group('on screen', () {
    testWidgets('a row shows who’s sharing, with TalkBack names', (
      tester,
    ) async {
      await _open(tester, _tab(_members));

      expect(find.text('+2'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Shared by you, Ari and 4 others',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a row fits a small phone', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _open(tester, _tab(_members, status: TabStatus.waiting));

      expect(tester.takeException(), isNull);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('Add tab’s Split between shows pictures', (tester) async {
      await _open(tester, _tab(_members));
      await tester.scrollUntilVisible(
        find.text('Add tab'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Add tab'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Bob'),
        200,
        scrollable: find.byType(Scrollable).last,
      );

      final row = find.widgetWithText(CheckboxListTile, 'Bob');
      expect(
        find.descendant(
          of: row,
          matching: find.byWidgetPredicate(
            (w) => w is PersonAvatar && w.uid == 'bob',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tab details show pictures for payers and shares', (
      tester,
    ) async {
      await _open(tester, _tab(const ['bob', 'cara']));
      await tester.tap(find.text('Dinner'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is PersonAvatar && w.uid == 'bob'),
        findsNWidgets(2),
      );
      expect(
        find.byWidgetPredicate((w) => w is PersonAvatar && w.uid == 'cara'),
        findsOneWidget,
      );
    });
  });
}
