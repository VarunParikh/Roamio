import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/budget/data/budget_service.dart';
import 'package:roamio/features/home/ui/needs_you.dart';
import 'package:roamio/features/profile/data/profile_service.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/tabs/data/tab_notice_service.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_budget_service.dart';
import '../../support/fake_invite_service.dart';
import '../../support/fake_notification_service.dart';
import '../../support/fake_profile_service.dart';
import '../../support/fake_squad_service.dart';
import '../../support/fake_tab_notice_service.dart';

final _now = Adventure(
  id: 'goa',
  name: 'Goa trip',
  countryCode: 'IN',
  startDate: DateTime(2026, 10, 20),
  endDate: DateTime(2026, 11, 3),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari'],
);

const _approve = TabNotice(
  id: 'n1',
  adventureId: 'goa',
  tabId: 't1',
  kind: TabNoticeKind.waiting,
  description: 'Dinner',
);
const _join = JoinCard(
  id: 'j1',
  adventureId: 'goa',
  adventureName: 'Goa trip',
  memberUid: 'ben',
  memberName: 'Ben Roy',
);
const _alert = BudgetAlert(
  id: 'b1',
  adventureId: 'goa',
  adventureName: 'Goa trip',
  threshold: 80,
);

const _titles = [
  '1 tab to approve',
  'Ben Roy joined your squad',
  'You’ve used 80% of your Goa trip budget',
  'We picked this for you',
  'Know when friends join',
];

/// Everything that can need you, apart from invites.
Future<void> _home(
  WidgetTester tester, {
  List<Adventure>? adventures,
  bool everything = true,
}) => pumpRoamio(
  tester,
  FakeAuthService(initial: readyFacts),
  adventures: FakeAdventureService(adventures ?? [_now]),
  tabNotices: FakeTabNoticeService(everything ? const [_approve] : const []),
  squad: FakeSquadService(everything ? const [_join] : const []),
  budgets: FakeBudgetService(alerts: everything ? const [_alert] : const []),
  profile: FakeProfileService(
    profile: Profile(name: 'Ari', characterOffered: !everything),
  ),
  notifications: FakeNotificationService(answer: everything ? null : false),
);

void main() {
  group('Needs you (spec UC-5)', () {
    testWidgets('nothing to do: no heading', (tester) async {
      await _home(tester, everything: false);
      expect(find.text('Needs you'), findsNothing);
      expect(find.text('See all'), findsNothing);
    });

    testWidgets('top 2 in order, then See all shows the rest in order', (
      tester,
    ) async {
      await _home(tester);
      expect(find.text('Needs you'), findsOneWidget);
      expect(find.text(_titles[0]), findsOneWidget);
      expect(find.text(_titles[1]), findsOneWidget);
      for (final hidden in _titles.skip(2)) {
        expect(find.text(hidden), findsNothing);
      }

      final seeAll = find.text('See all');
      await tester.ensureVisible(seeAll);
      await tester.pumpAndSettle();
      await tester.tap(seeAll);
      await tester.pumpAndSettle();
      final shown = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('needs-you-items')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .where(_titles.contains)
          .toList();
      expect(shown, _titles);

      await tester.ensureVisible(find.text('Show fewer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show fewer'));
      await tester.pumpAndSettle();
      expect(find.text(_titles[2]), findsNothing);
    });

    testWidgets('invites come after tabs to approve', (tester) async {
      final invites = FakeInviteService()..saved.add('7KQ2M9XA');
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_now]),
        tabNotices: FakeTabNoticeService(const [_approve]),
        invites: invites,
        profile: FakeProfileService(profile: const Profile(name: 'Ari')),
      );
      final column = tester.widget<Column>(
        find.byKey(const ValueKey('needs-you-items')),
      );
      expect(column.children.map((c) => c.key), [
        const ValueKey('notice-waiting-goa'),
        const ValueKey('invite-7KQ2M9XA'),
      ]);
    });

    testWidgets('two or fewer: no See all', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_now]),
        tabNotices: FakeTabNoticeService(const [_approve]),
        profile: FakeProfileService(profile: const Profile(name: 'Ari')),
      );
      expect(find.text(_titles[0]), findsOneWidget);
      expect(find.text('See all'), findsNothing);
    });

    testWidgets('sits under the adventure card, above New adventure', (
      tester,
    ) async {
      await _home(tester);
      final card = tester.getBottomLeft(find.text('Add tab')).dy;
      final heading = tester.getTopLeft(find.text('Needs you')).dy;
      expect(heading, greaterThan(card));
      final newAdventure = find.text('New adventure');
      await tester.ensureVisible(newAdventure);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(newAdventure).dy,
        greaterThan(tester.getTopLeft(find.text('Needs you')).dy),
      );
    });

    testWidgets('a phone still refreshes its push ID when no prompt shows', (
      tester,
    ) async {
      final notifications = FakeNotificationService(answer: true);
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_now]),
        notifications: notifications,
      );
      expect(notifications.calls, contains('refresh'));
    });

    testWidgets('all five fit a small phone', (tester) async {
      await _home(tester);
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      await tester.pumpAndSettle();
      final seeAll = find.text('See all');
      await tester.ensureVisible(seeAll);
      await tester.pumpAndSettle();
      await tester.tap(seeAll);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(NeedsYou), findsOneWidget);
    });
  });
}
