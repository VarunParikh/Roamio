import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/invites/data/invite_service.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_invite_service.dart';

final _bangkok = Adventure(
  id: 'bkk',
  name: 'Bangkok trip',
  countryCode: 'TH',
  startDate: DateTime(2026, 12),
  endDate: DateTime(2026, 12, 8),
  baseCurrency: 'THB',
  leaderUid: 'ari',
  memberUids: const ['ari', 'bob'],
);

final _goaInvite = InviteDetails(
  code: '7KQ2M9XA',
  adventureId: 'goa',
  adventureName: 'Goa getaway',
  leaderName: 'Cara',
  countryCode: 'IN',
  startDate: DateTime(2026, 12, 20),
  endDate: DateTime(2026, 12, 27),
);

void main() {
  group('leads share an invite (UC-9)', () {
    testWidgets('Share invite sends the link and code to the share sheet', (
      tester,
    ) async {
      final invites = FakeInviteService();
      final shared = <String>[];
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_bangkok]),
        invites: invites,
        shared: shared,
      );
      await tester.tap(find.text('Bangkok trip'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Share invite'), 200);
      await tester.tap(find.text('Share invite'));
      await tester.pumpAndSettle();

      expect(invites.calls, ['create:bkk']);
      expect(shared.single, contains('“Bangkok trip”'));
      expect(
        shared.single,
        contains('https://roamio-dev-varun.web.app/i/ABCDEFGH'),
      );
      expect(shared.single, contains('ABCD-EFGH'));
      expect(find.text('ABCD-EFGH'), findsOneWidget);
    });

    testWidgets('a new link replaces the old one after confirming', (
      tester,
    ) async {
      final invites = FakeInviteService();
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_bangkok]),
        invites: invites,
      );
      await tester.tap(find.text('Bangkok trip'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Share invite'), 200);
      await tester.tap(find.text('Share invite'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Make a new link'), 200);
      await tester.tap(find.text('Make a new link'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New link'));
      await tester.pumpAndSettle();

      expect(invites.calls, ['create:bkk', 'revoke:bkk', 'create:bkk']);
      expect(find.text('ABCD-JKMN'), findsOneWidget);
    });

    testWidgets('members are pointed to the leader instead', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(
          initial: const SessionFacts(
            uid: 'bob',
            hasAccount: true,
            ageStatus: 'adult',
          ),
        ),
        adventures: FakeAdventureService([_bangkok]),
      );
      await tester.tap(find.text('Bangkok trip'));
      await tester.pumpAndSettle();
      expect(find.text('Share invite'), findsNothing);
      expect(
        find.text(
          'Want to add someone? Ask the squad leader for the invite link.',
        ),
        findsOneWidget,
      );
    });
  });

  group('invitees add an invite (UC-12, UC-13)', () {
    testWidgets('Have an invite code? finds and saves it to Invites', (
      tester,
    ) async {
      final invites = FakeInviteService(valid: {'7KQ2M9XA': _goaInvite});
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        invites: invites,
      );

      await tester.scrollUntilVisible(
        find.text('Have an invite code?'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Have an invite code?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nope');
      await tester.tap(find.text('Find invite'));
      await tester.pumpAndSettle();
      expect(
        find.text('That doesn’t look like a Roamio invite code.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '7kq2-m9xa');
      await tester.tap(find.text('Find invite'));
      await tester.pumpAndSettle();

      expect(invites.saved, ['7KQ2M9XA']);
      expect(find.text('Invites'), findsOneWidget);
      expect(find.text('🇮🇳  Goa getaway'), findsOneWidget);
      expect(find.textContaining('From Cara'), findsOneWidget);
    });

    testWidgets('an expired code explains itself and saves nothing', (
      tester,
    ) async {
      final invites = FakeInviteService()
        ..unknownMessage = 'This invite has expired. Ask for a new one.';
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        invites: invites,
      );
      await tester.scrollUntilVisible(
        find.text('Have an invite code?'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Have an invite code?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ABCDEFGH');
      await tester.tap(find.text('Find invite'));
      await tester.pumpAndSettle();
      expect(
        find.text('This invite has expired. Ask for a new one.'),
        findsOneWidget,
      );
      expect(invites.saved, isEmpty);
    });

    testWidgets('offers a code it finds on the clipboard', (tester) async {
      final invites = FakeInviteService(valid: {'7KQ2M9XA': _goaInvite});
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        invites: invites,
        clipboard:
            'Join my Roamio adventure! Or enter code 7KQ2-M9XA in the app.',
      );
      expect(find.text('Found invite code 7KQ2-M9XA. Use it?'), findsOneWidget);
      await tester.tap(find.text('Use'));
      await tester.pumpAndSettle();
      expect(invites.saved, ['7KQ2M9XA']);
    });

    testWidgets('an invite link opened before signing up waits for sign-in', (
      tester,
    ) async {
      final auth = FakeAuthService();
      final invites = FakeInviteService(valid: {'7KQ2M9XA': _goaInvite});
      await pumpRoamio(tester, auth, invites: invites);

      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/i/7KQ2M9XA');
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);

      auth.emit(readyFacts);
      await tester.pumpAndSettle();
      expect(invites.saved, ['7KQ2M9XA']);
      expect(find.text('🇮🇳  Goa getaway'), findsOneWidget);
    });

    testWidgets('a bad invite link says why and offers Home', (tester) async {
      await pumpRoamio(tester, FakeAuthService(initial: readyFacts));
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/i/ZZZZZZZZ');
      await tester.pumpAndSettle();
      expect(find.text('This invite can’t be used'), findsOneWidget);
      await tester.tap(find.text('Go to Home'));
      await tester.pumpAndSettle();
      expect(find.text('Hey Ari 👋'), findsOneWidget);
    });
  });
}
