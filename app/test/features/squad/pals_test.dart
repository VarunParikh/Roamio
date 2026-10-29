import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/squad/data/squad_service.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_squad_service.dart';

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

Future<FakeSquadService> _open(WidgetTester tester, {String as = 'ari'}) async {
  final squad = FakeSquadService()
    ..names.addAll({'ari': 'Ari Chen', 'cara': 'Cara Diaz', 'bob': 'Bob Lee'})
    ..palsByAdventure['bkk'] = [const Pal(id: 'kiko', nickname: 'Kiko')];
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
  return squad;
}

Finder _menuFor(String name) => find.descendant(
  of: find.widgetWithText(ListTile, name),
  matching: find.byTooltip('Options'),
);

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

    testWidgets('a lead adds a pal by nickname only', (tester) async {
      final squad = await _open(tester, as: 'cara');

      await tester.tap(find.text('Add pal'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('nickname'), findsWidgets);

      await tester.enterText(find.byType(TextField), '  kiko ');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.text('There’s already a pal called Kiko.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  Lu  ');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(squad.calls, ['addPal:bkk/Lu']);
      expect(find.widgetWithText(ListTile, 'Lu'), findsOneWidget);
      expect(find.text('Squad (5)'), findsOneWidget);
    });

    testWidgets('a lead renames and removes a pal', (tester) async {
      final squad = await _open(tester);

      await tester.tap(_menuFor('Kiko'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Kiks');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(squad.calls, ['renamePal:kiko/Kiks']);

      await tester.tap(_menuFor('Kiks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from squad'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Kiks from Bangkok trip?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(squad.calls.last, 'removePal:kiko');
      expect(find.widgetWithText(ListTile, 'Kiks'), findsNothing);
    });

    testWidgets('an empty nickname is refused', (tester) async {
      final squad = await _open(tester);

      await tester.tap(find.text('Add pal'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a nickname.'), findsOneWidget);
      expect(squad.calls, isEmpty);
    });
  });
}
