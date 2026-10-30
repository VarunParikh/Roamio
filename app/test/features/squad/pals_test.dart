import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/profile/domain/characters.dart';
import 'package:roamio/features/splits/data/settlement_service.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/ui/tabs_section.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_settlement_service.dart';
import '../../support/fake_squad_service.dart';
import '../../support/fake_tab_service.dart';

/// Ari leads, Cara is co-lead, Bob is a member; Kiko is a pal.
final _bangkok = Adventure(
  id: 'bkk',
  name: 'Bangkok trip',
  countryCode: 'TH',
  startDate: DateTime(2026, 12),
  endDate: DateTime(2026, 12, 8),
  baseCurrency: 'THB',
  leaderUid: 'ari',
  coLeadUids: const ['cara'],
  memberUids: const ['ari', 'cara', 'bob'],
);

Future<FakeSquadService> _open(
  WidgetTester tester, {
  String as = 'ari',
  String? kiko,
  String? removed,
  Map<String, String> characters = const {},
}) async {
  final squad = FakeSquadService()
    ..names.addAll({'ari': 'Ari Chen', 'cara': 'Cara Diaz', 'bob': 'Bob Lee'})
    ..characters.addAll(characters)
    ..palsByAdventure['bkk'] = [
      Pal(id: 'kiko', nickname: 'Kiko', characterId: kiko),
    ]
    ..removedByAdventure['bkk'] = [
      if (removed != null) Pal(id: 'lu', nickname: 'Lu', characterId: removed),
    ];
  await pumpRoamio(
    tester,
    FakeAuthService(
      initial: SessionFacts(uid: as, hasAccount: true, ageStatus: 'adult'),
    ),
    adventures: FakeAdventureService([_bangkok]),
    squad: squad,
  );
  await tester.tap(find.text('Bangkok trip'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Leave adventure'), 200);
  // Lift it clear of the floating Add tab button.
  await tester.drag(find.text('Leave adventure'), const Offset(0, -200));
  await tester.pumpAndSettle();
  return squad;
}

Finder _menuFor(String name) => find.descendant(
  of: find.widgetWithText(ListTile, name),
  matching: find.byTooltip('Options'),
);

Finder _picture(String id) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == 'assets/characters/$id.webp',
);

bool _dimmed(String id) => find
    .ancestor(of: _picture(id), matching: find.byType(Opacity))
    .evaluate()
    .isNotEmpty;

FilledButton _button(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

Future<void> _tapOn(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openForm(WidgetTester tester) async {
  await _tapOn(tester, find.text('Add pal'));
}

Future<void> _pick(WidgetTester tester, String label) async {
  await _tapOn(tester, find.text('Choose a character'));
  await _tapOn(tester, find.bySemanticsLabel(label));
}

void main() {
  group('pals (UC-18)', () {
    testWidgets('are listed in the squad with a Pal badge', (tester) async {
      await _open(tester, as: 'bob');

      expect(find.text('Squad (4)'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Kiko'), findsOneWidget);
      expect(find.text('Pal'), findsOneWidget);
      // Members can't manage pals.
      expect(find.text('Add pal'), findsNothing);
      expect(_menuFor('Kiko'), findsNothing);
    });

    testWidgets('a pal shows their character', (tester) async {
      await _open(tester, as: 'bob', kiko: 'owl');

      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Kiko'),
          matching: _picture('owl'),
        ),
        findsOneWidget,
      );
    });

    for (final (label, id) in [('missing', null), ('unknown', 'gone_now')]) {
      testWidgets('a $label character shows the default', (tester) async {
        await _open(tester, as: 'bob', kiko: id);

        expect(
          find.descendant(
            of: find.widgetWithText(ListTile, 'Kiko'),
            matching: _picture(defaultCharacterFor('kiko').id),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('Add stays disabled, with the reason, until both are filled', (
      tester,
    ) async {
      final squad = await _open(tester, as: 'cara');
      await _openForm(tester);

      expect(find.text('Add a pal'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(_button(tester, 'Add').onPressed, isNull);
      expect(
        find.text('Add a nickname and choose a character.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '  Lu  ');
      await tester.pump();
      expect(_button(tester, 'Add').onPressed, isNull);
      expect(find.text('Choose a character.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(
        find.text('Add a nickname and choose a character.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '  Lu  ');
      await _pick(tester, 'Traveller 2');
      expect(find.text('Choose a character.'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(_button(tester, 'Add').onPressed, isNull);
      expect(find.text('Add a nickname.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  kiko ');
      await tester.pump();
      expect(_button(tester, 'Add').onPressed, isNull);
      expect(find.text('There’s already a pal called Kiko.'), findsOneWidget);
      expect(squad.calls, isEmpty);

      await tester.enterText(find.byType(TextField), '  Lu  ');
      await tester.pump();
      await _tapOn(tester, find.widgetWithText(FilledButton, 'Add'));

      expect(squad.calls, ['addPal:bkk/Lu/traveller_02']);
      expect(find.widgetWithText(ListTile, 'Lu'), findsOneWidget);
      expect(find.text('Squad (5)'), findsOneWidget);
    });

    testWidgets('closing the picker keeps the nickname, and has no skip', (
      tester,
    ) async {
      await _open(tester);
      await _openForm(tester);
      await tester.enterText(find.byType(TextField), 'Lu');
      await _tapOn(tester, find.text('Choose a character'));

      expect(find.text('Choose a character for Lu'), findsOneWidget);
      expect(find.textContaining('Skip'), findsNothing);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Choose a character for Lu'), findsNothing);
      expect(find.text('Lu'), findsOneWidget);
      expect(find.text('Choose a character.'), findsOneWidget);
      expect(_button(tester, 'Add').onPressed, isNull);
    });

    testWidgets('characters used in this squad are dimmed but can be chosen', (
      tester,
    ) async {
      final squad = await _open(
        tester,
        kiko: 'traveller_01',
        characters: {'bob': 'traveller_02'},
      );
      await _openForm(tester);
      await tester.enterText(find.byType(TextField), 'Lu');
      await _tapOn(tester, find.text('Choose a character'));

      expect(_dimmed('traveller_01'), isTrue, reason: 'Kiko, a pal');
      expect(_dimmed('traveller_02'), isTrue, reason: 'Bob, a member');
      expect(_dimmed('traveller_03'), isFalse);

      await _tapOn(tester, find.bySemanticsLabel('Traveller 1'));
      await _tapOn(tester, find.widgetWithText(FilledButton, 'Add'));
      expect(squad.calls, ['addPal:bkk/Lu/traveller_01']);
    });

    testWidgets('a removed pal’s character is free again', (tester) async {
      await _open(tester, kiko: 'traveller_01', removed: 'traveller_02');
      await _openForm(tester);
      await _tapOn(tester, find.text('Choose a character'));

      expect(_dimmed('traveller_01'), isTrue);
      expect(_dimmed('traveller_02'), isFalse);
    });

    testWidgets('a lead edits both, and Rename is gone', (tester) async {
      final squad = await _open(tester, as: 'cara', kiko: 'traveller_01');

      await _tapOn(tester, _menuFor('Kiko'));
      expect(find.text('Rename'), findsNothing);
      await _tapOn(tester, find.text('Edit'));

      expect(find.text('Edit Kiko'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Kiko'), findsOneWidget);
      expect(_picture('traveller_01'), findsOneWidget);
      expect(_button(tester, 'Save').onPressed, isNotNull);

      await tester.enterText(find.byType(TextField), 'Kiks');
      await _tapOn(tester, find.text('Change character'));
      expect(find.text('Choose a character for Kiks'), findsOneWidget);
      // Their own character isn't "used" by someone else.
      expect(_dimmed('traveller_01'), isFalse);
      await _tapOn(tester, find.bySemanticsLabel('Traveller 3'));
      await _tapOn(tester, find.widgetWithText(FilledButton, 'Save'));

      expect(squad.calls, ['editPal:kiko/Kiks/traveller_03']);
      expect(find.widgetWithText(ListTile, 'Kiks'), findsOneWidget);
    });

    testWidgets('a pal from before characters must choose one to save', (
      tester,
    ) async {
      final squad = await _open(tester);

      await _tapOn(tester, _menuFor('Kiko'));
      await _tapOn(tester, find.text('Edit'));

      expect(_picture(defaultCharacterFor('kiko').id), findsOneWidget);
      expect(_button(tester, 'Save').onPressed, isNull);
      expect(find.text('Choose a character.'), findsOneWidget);

      await _pick(tester, 'Traveller 4');
      await _tapOn(tester, find.widgetWithText(FilledButton, 'Save'));
      expect(squad.calls, ['editPal:kiko/Kiko/traveller_04']);
    });

    testWidgets('removing asks first', (tester) async {
      final squad = await _open(tester);

      await _tapOn(tester, _menuFor('Kiko'));
      await _tapOn(tester, find.text('Remove from squad'));
      expect(find.text('Remove Kiko from Bangkok trip?'), findsOneWidget);
      await _tapOn(tester, find.widgetWithText(FilledButton, 'Remove'));

      expect(squad.calls.last, 'removePal:kiko');
      expect(find.widgetWithText(ListTile, 'Kiko'), findsNothing);
    });

    testWidgets('adding offline doesn’t wait for the server', (tester) async {
      final squad = await _open(tester);
      squad.palWrite = Completer<void>();
      await _openForm(tester);
      await tester.enterText(find.byType(TextField), 'Lu');
      await _pick(tester, 'Traveller 2');
      await _tapOn(tester, find.widgetWithText(FilledButton, 'Add'));

      expect(squad.palWrite!.isCompleted, isFalse);
      expect(find.text('Add a pal'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Lu'), findsOneWidget);
    });

    testWidgets('editing offline doesn’t wait for the server', (tester) async {
      final squad = await _open(tester, kiko: 'traveller_01');
      squad.palWrite = Completer<void>();
      await _tapOn(tester, _menuFor('Kiko'));
      await _tapOn(tester, find.text('Edit'));
      await tester.enterText(find.byType(TextField), 'Kiks');
      await tester.pump();
      await _tapOn(tester, find.widgetWithText(FilledButton, 'Save'));

      expect(find.text('Edit Kiko'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Kiks'), findsOneWidget);
    });
  });

  group('squadPeople', () {
    Map<String, SquadPerson>? people;

    Future<void> pump(WidgetTester tester, FakeSquadService squad) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadServiceProvider.overrideWithValue(squad),
            tabServiceProvider.overrideWithValue(FakeTabService()),
            settlementServiceProvider.overrideWithValue(
              FakeSettlementService(),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              people = squadPeople(ref, _bangkok);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('passes on pals’ characters, removed pals’ too', (
      tester,
    ) async {
      final squad = FakeSquadService()
        ..palsByAdventure['bkk'] = [
          const Pal(id: 'kiko', nickname: 'Kiko', characterId: 'owl'),
          const Pal(id: 'old', nickname: 'Old'),
        ]
        ..removedByAdventure['bkk'] = [
          const Pal(id: 'lu', nickname: 'Lu', characterId: 'fox'),
        ];
      await pump(tester, squad);

      expect(people!['kiko']!.characterId, 'owl');
      expect(people!['old']!.characterId, isNull);
      expect(people!['old']!.deleted, isFalse);
      expect(people!['lu']!.name, 'Lu');
      expect(people!['lu']!.characterId, 'fox');
      expect(people!['lu']!.deleted, isFalse);
    });
  });
}
