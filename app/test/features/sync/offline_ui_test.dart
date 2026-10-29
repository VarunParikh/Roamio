import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/squad/data/squad_service.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_squad_service.dart';
import '../../support/fake_sync.dart';

const _syncText =
    'We know the data might be of essence, click here to sync the '
    'adventure with your squad';

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

Future<void> _openBangkok(WidgetTester tester) async {
  await tester.tap(find.text('Bangkok trip'));
  await tester.pumpAndSettle();
}

void main() {
  group('offline banner and Sync (UC-31)', () {
    testWidgets('online: no banner', (tester) async {
      await pumpRoamio(tester, FakeAuthService(initial: readyFacts));
      expect(find.textContaining('offline'), findsNothing);
      expect(find.text(_syncText), findsNothing);
    });

    testWidgets('offline: says changes are kept, with one next step', (
      tester,
    ) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        connectivity: FakeConnectivity(online: false),
      );
      expect(find.textContaining('You’re offline'), findsOneWidget);
      expect(find.text('Sync'), findsNothing);
    });

    testWidgets('back online: the spec text and a Sync button', (tester) async {
      final connectivity = FakeConnectivity(online: false);
      final network = FakeNetworkSwitch();
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        connectivity: connectivity,
        network: network,
      );

      connectivity.set(online: true);
      await tester.pumpAndSettle();
      expect(find.text(_syncText), findsOneWidget);

      await tester.tap(find.text('Sync'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Synced ✓'), findsOneWidget);
      expect(network.calls, ['disable', 'enable', 'writes']);

      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Synced ✓'), findsNothing);
    });

    testWidgets('a failed sync shows the error and Try again', (tester) async {
      final connectivity = FakeConnectivity(online: false);
      final network = FakeNetworkSwitch();
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        connectivity: connectivity,
        network: network,
      );
      connectivity.set(online: true);
      await tester.pumpAndSettle();
      network.failWrites = Exception('permission-denied');

      await tester.tap(find.text('Sync'));
      await tester.pumpAndSettle();

      expect(find.textContaining('permission-denied'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Synced ✓'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('the adventure page shows it too', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_bangkok]),
        connectivity: FakeConnectivity(online: false),
      );
      await _openBangkok(tester);
      expect(find.textContaining('You’re offline'), findsOneWidget);
    });
  });

  group('online-only actions are disabled offline (UC-33)', () {
    testWidgets('inviting, with the reason', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_bangkok]),
        connectivity: FakeConnectivity(online: false),
      );
      await _openBangkok(tester);
      await tester.scrollUntilVisible(find.text('Share invite'), 200);

      final share = find.ancestor(
        of: find.text('Share invite'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(tester.widget<ButtonStyleButton>(share).onPressed, isNull);
      expect(find.textContaining('Needs a connection'), findsWidgets);
    });

    testWidgets('leaving, and role changes', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_bangkok]),
        connectivity: FakeConnectivity(online: false),
      );
      await _openBangkok(tester);
      await tester.scrollUntilVisible(find.text('Leave adventure'), 200);

      final leave = find.ancestor(
        of: find.text('Leave adventure'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(tester.widget<ButtonStyleButton>(leave).onPressed, isNull);
      expect(find.byTooltip('Options'), findsNothing);
    });

    testWidgets('a join card’s Make co-lead and Remove, with the reason', (
      tester,
    ) async {
      final squad = FakeSquadService([
        const JoinCard(
          id: 'bkk_joined_bob',
          adventureId: 'bkk',
          adventureName: 'Bangkok trip',
          memberUid: 'bob',
          memberName: 'Bob Lee',
        ),
      ]);
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_bangkok]),
        squad: squad,
        connectivity: FakeConnectivity(online: false),
      );

      expect(find.text('Bob Lee joined your squad'), findsOneWidget);
      for (final label in ['Make co-lead', 'Remove']) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
      }
      expect(find.textContaining('Needs a connection'), findsWidgets);
      // Dismissing only hides the card, so it still works offline.
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(squad.cards, isEmpty);
    });

    testWidgets('entering an invite code', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        connectivity: FakeConnectivity(online: false),
      );
      await tester.tap(find.text('Have an invite code?'));
      await tester.pumpAndSettle();

      final find_ = find.ancestor(
        of: find.text('Find invite'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(tester.widget<ButtonStyleButton>(find_).onPressed, isNull);
    });
  });
}
