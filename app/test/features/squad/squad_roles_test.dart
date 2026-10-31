import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/profile/ui/character_avatar.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_squad_service.dart';

/// Ari leads, Cara is co-lead, Bob is a member.
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

FakeSquadService _squad() => FakeSquadService()
  ..names.addAll({'ari': 'Ari Chen', 'cara': 'Cara Diaz', 'bob': 'Bob Lee'});

Future<FakeSquadService> _open(
  WidgetTester tester, {
  String as = 'ari',
  Adventure? adventure,
}) async {
  final squad = _squad();
  await pumpRoamio(
    tester,
    FakeAuthService(
      initial: SessionFacts(uid: as, hasAccount: true, ageStatus: 'adult'),
    ),
    adventures: FakeAdventureService([adventure ?? _bangkok]),
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

void main() {
  testWidgets('the squad list shows the character each person chose', (
    tester,
  ) async {
    final squad = _squad()..characters['bob'] = 'panda';
    await pumpRoamio(
      tester,
      FakeAuthService(
        initial: const SessionFacts(
          uid: 'ari',
          hasAccount: true,
          ageStatus: 'adult',
        ),
      ),
      adventures: FakeAdventureService([_bangkok]),
      squad: squad,
    );
    await tester.tap(find.text('Bangkok trip'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Bob Lee'), 200);

    final bob = find.widgetWithText(ListTile, 'Bob Lee');
    expect(
      find.descendant(
        of: bob,
        matching: find.byWidgetPredicate(
          (w) =>
              w is CharacterAvatar &&
              w.characterId == 'panda' &&
              w.uid == 'bob',
        ),
      ),
      findsOneWidget,
    );
    // Someone who hasn't chosen has their default, never a blank.
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Cara Diaz'),
        matching: find.byWidgetPredicate(
          (w) => w is CharacterAvatar && w.uid == 'cara' && !w.loading,
        ),
      ),
      findsOneWidget,
    );
  });

  group('squad list (UC-15)', () {
    testWidgets('shows everyone with their role and a 🎩 on leads', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text('Squad (3)'), findsOneWidget);
      expect(find.text('Ari Chen (you)'), findsOneWidget);
      expect(find.text('Squad leader'), findsOneWidget);
      expect(find.text('Co-lead'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget);
      expect(find.text('🎩'), findsNWidgets(2));
    });

    testWidgets('the leader promotes, demotes and hands over', (tester) async {
      final squad = await _open(tester);

      await tester.tap(_menuFor('Bob Lee'));
      await tester.pumpAndSettle();
      expect(find.text('Make co-lead'), findsOneWidget);
      expect(find.text('Make squad leader'), findsOneWidget);
      expect(find.text('Remove from squad'), findsOneWidget);
      await tester.tap(find.text('Make co-lead'));
      await tester.pumpAndSettle();
      expect(squad.calls, ['coLead:bkk/bob']);

      await tester.tap(_menuFor('Cara Diaz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make member'));
      await tester.pumpAndSettle();
      expect(squad.calls.last, 'demote:bkk/cara');

      await tester.tap(_menuFor('Bob Lee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make squad leader'));
      await tester.pumpAndSettle();
      expect(find.text('Make Bob Lee squad leader?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Hand over'));
      await tester.pumpAndSettle();
      expect(squad.calls.last, 'handOver:bkk/bob');
    });

    testWidgets('co-leads can only remove members', (tester) async {
      final squad = await _open(tester, as: 'cara');

      expect(_menuFor('Ari Chen'), findsNothing);
      await tester.tap(_menuFor('Bob Lee'));
      await tester.pumpAndSettle();
      expect(find.text('Make co-lead'), findsNothing);
      expect(find.text('Make squad leader'), findsNothing);
      await tester.tap(find.text('Remove from squad'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(squad.calls, ['remove:bkk/bob']);
    });

    testWidgets('members get no options on anyone', (tester) async {
      await _open(tester, as: 'bob');
      expect(find.byTooltip('Options'), findsNothing);
    });
  });

  group('leaving (UC-16, UC-17)', () {
    testWidgets('a member confirms, leaves and goes Home', (tester) async {
      final squad = await _open(tester, as: 'bob');

      await tester.tap(find.text('Leave adventure'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
      await tester.pumpAndSettle();

      expect(squad.calls, ['leave:bkk']);
      expect(find.textContaining('Hey'), findsOneWidget);
    });

    testWidgets('the leader is asked to hand over first', (tester) async {
      final squad = await _open(tester);

      await tester.tap(find.text('Leave adventure'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Make someone else squad leader'), findsOne);
      expect(find.widgetWithText(FilledButton, 'Leave'), findsNothing);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(squad.calls, isEmpty);
    });

    testWidgets('a leader on their own is told it archives the adventure', (
      tester,
    ) async {
      final squad = await _open(
        tester,
        adventure: Adventure(
          id: 'bkk',
          name: 'Bangkok trip',
          countryCode: 'TH',
          startDate: DateTime(2026, 12),
          endDate: DateTime(2026, 12, 8),
          baseCurrency: 'THB',
          leaderUid: 'ari',
          memberUids: const ['ari'],
        ),
      );

      await tester.tap(find.text('Leave adventure'));
      await tester.pumpAndSettle();
      expect(find.textContaining('archive'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
      await tester.pumpAndSettle();
      expect(squad.calls, ['leave:bkk']);
    });
  });
}
