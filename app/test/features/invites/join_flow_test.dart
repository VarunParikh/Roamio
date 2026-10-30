import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/invites/data/invite_service.dart';
import 'package:roamio/features/squad/data/squad_service.dart';

import 'package:roamio/features/squad/ui/person.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_invite_service.dart';
import '../../support/fake_squad_service.dart';

final _goaInvite = InviteDetails(
  code: '7KQ2M9XA',
  adventureId: 'goa',
  adventureName: 'Goa getaway',
  leaderName: 'Cara',
  countryCode: 'IN',
  startDate: DateTime(2026, 12, 20),
  endDate: DateTime(2026, 12, 27),
);

Adventure _bangkok({String leader = 'ari', List<String> coLeads = const []}) =>
    Adventure(
      id: 'bkk',
      name: 'Bangkok trip',
      countryCode: 'TH',
      startDate: DateTime(2026, 12),
      endDate: DateTime(2026, 12, 8),
      baseCurrency: 'THB',
      leaderUid: leader,
      coLeadUids: coLeads,
      memberUids: {leader, 'ari', ...coLeads, 'bob'}.toList(),
    );

const _bobJoined = JoinCard(
  id: 'bkk_joined_bob',
  adventureId: 'bkk',
  adventureName: 'Bangkok trip',
  memberUid: 'bob',
  memberName: 'Bob Lee',
);

void main() {
  group('Join squad (UC-13)', () {
    testWidgets('joins from the Invites list and says so', (tester) async {
      final invites = FakeInviteService(valid: {'7KQ2M9XA': _goaInvite})
        ..saved.add('7KQ2M9XA');
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        invites: invites,
      );

      expect(find.textContaining('next update'), findsNothing);
      await tester.tap(find.text('Join squad'));
      await tester.pumpAndSettle();

      expect(invites.joined, ['7KQ2M9XA']);
      expect(invites.saved, isEmpty);
      expect(find.text('Invites'), findsNothing);
      expect(find.textContaining('You’re in'), findsOneWidget);
    });

    testWidgets('a refused join explains why and keeps the invite', (
      tester,
    ) async {
      final invites = FakeInviteService(valid: {'7KQ2M9XA': _goaInvite})
        ..saved.add('7KQ2M9XA')
        ..joinError = 'This adventure has already ended.';
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        invites: invites,
      );

      await tester.tap(find.text('Join squad'));
      await tester.pumpAndSettle();

      expect(find.text('This adventure has already ended.'), findsOneWidget);
      expect(invites.saved, ['7KQ2M9XA']);
      expect(find.text('Join squad'), findsOneWidget);
    });
  });

  group('lead card when someone joins (UC-14)', () {
    testWidgets('the card shows the picture of who joined', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_bangkok()]),
        squad: FakeSquadService([_bobJoined]),
      );

      expect(
        find.byWidgetPredicate((w) => w is PersonAvatar && w.uid == 'bob'),
        findsOneWidget,
      );
    });

    testWidgets('the leader sees Make co-lead and Remove', (tester) async {
      final squad = FakeSquadService([_bobJoined]);
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_bangkok()]),
        squad: squad,
      );

      expect(find.text('Bob Lee joined your squad'), findsOneWidget);
      expect(find.textContaining('Bangkok trip'), findsWidgets);
      await tester.tap(find.text('Make co-lead'));
      await tester.pumpAndSettle();

      expect(squad.calls, ['coLead:bkk/bob']);
      expect(find.text('Bob Lee joined your squad'), findsNothing);
      expect(find.text('Bob Lee is now a co-lead.'), findsOneWidget);
    });

    testWidgets('Remove asks first, then removes', (tester) async {
      final squad = FakeSquadService([_bobJoined]);
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_bangkok()]),
        squad: squad,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Bob Lee from Bangkok trip?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(squad.calls, isEmpty);

      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(squad.calls, ['remove:bkk/bob']);
      expect(find.text('Bob Lee joined your squad'), findsNothing);
    });

    testWidgets('co-leads can remove but not promote (UC-15)', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([
          _bangkok(leader: 'cara', coLeads: ['ari']),
        ]),
        squad: FakeSquadService([_bobJoined]),
      );

      expect(find.text('Bob Lee joined your squad'), findsOneWidget);
      expect(find.text('Make co-lead'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Remove'), findsOneWidget);
    });

    testWidgets('can be dismissed, and failures say why', (tester) async {
      final squad = FakeSquadService([_bobJoined])
        ..failNext = 'No connection. Check your internet and try again.';
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_bangkok()]),
        squad: squad,
      );

      await tester.tap(find.text('Make co-lead'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No connection'), findsOneWidget);
      expect(find.text('Bob Lee joined your squad'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(squad.calls.last, 'dismiss:bkk_joined_bob');
      expect(find.text('Bob Lee joined your squad'), findsNothing);
    });
  });
}
