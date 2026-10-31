import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/data/activity_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/activity_screen.dart';
import 'package:roamio/features/adventures/ui/adventure_page.dart';
import 'package:roamio/features/squad/ui/person.dart';

import '../../support/fake_activity_service.dart';
import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_squad_service.dart';

/// "Today" is 29 Oct 2026 in pumpRoamio.
Adventure _trip(String id, DateTime start, DateTime end) => Adventure(
  id: id,
  name: 'Trip $id',
  countryCode: 'IN',
  startDate: start,
  endDate: end,
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari', 'ben'],
);

final Adventure _newer = _trip(
  'newer',
  DateTime(2026, 10, 27),
  DateTime(2026, 11, 3),
);
final Adventure _older = _trip(
  'older',
  DateTime(2026, 10),
  DateTime(2026, 11, 30),
);
final Adventure _next = _trip(
  'next',
  DateTime(2026, 11, 4),
  DateTime(2026, 11, 9),
);
final Adventure _old = _trip('old', DateTime(2026, 6), DateTime(2026, 6, 5));

ActivityEntry _joined(String id, String who, DateTime? at) => ActivityEntry(
  id: id,
  type: 'member_joined',
  actorUid: who,
  subject: who,
  createdAt: at,
);

Future<FakeActivityService> _home(
  WidgetTester tester, {
  List<Adventure>? adventures,
  Map<String, List<ActivityEntry>> activity = const {},
}) async {
  final service = FakeActivityService(activity);
  await pumpRoamio(
    tester,
    FakeAuthService(initial: readyFacts),
    adventures: FakeAdventureService(adventures ?? [_newer, _older, _next]),
    activity: service,
    squad: FakeSquadService()
      ..names.addAll({'ari': 'Ari Chen', 'ben': 'Ben Roy'}),
  );
  return service;
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('other trips (spec UC-5)', () {
    testWidgets('two trips at once: the latest started leads; the other is '
        'under Also happening now', (tester) async {
      await _home(tester);
      expect(find.text('CURRENT ADVENTURE'), findsOneWidget);
      await _scrollTo(tester, find.text('Also happening now'));
      await _scrollTo(tester, find.text('Trip older'));
      expect(find.text('1 Oct – 30 Nov 2026 · 32 days left'), findsOneWidget);
    });

    testWidgets('Upcoming is future only, with the date beside the card', (
      tester,
    ) async {
      await _home(tester);
      await _scrollTo(tester, find.text('Upcoming adventures'));
      await _scrollTo(tester, find.text('Trip next'));
      final date = find.byKey(const ValueKey('date-next'));
      expect(
        find.descendant(of: date, matching: find.text('4')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: date, matching: find.text('Nov 2026')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: date, matching: find.text('WED')),
        findsOneWidget,
      );
      expect(
        tester.getTopRight(date).dx,
        lessThanOrEqualTo(tester.getTopLeft(find.text('Trip next')).dx),
      );
    });

    testWidgets('with no current trip, the next leads and no Also now', (
      tester,
    ) async {
      await _home(tester, adventures: [_next, _old]);
      expect(find.text('NEXT ADVENTURE'), findsOneWidget);
      expect(find.text('Also happening now'), findsNothing);
      expect(find.text('Upcoming adventures'), findsNothing);
    });

    testWidgets('tapping another trip opens it', (tester) async {
      await _home(tester);
      await _scrollTo(tester, find.text('Trip next'));
      await tester.tap(find.text('Trip next'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AdventurePage>(find.byType(AdventurePage)).adventureId,
        'next',
      );
    });

    testWidgets('fits a small phone', (tester) async {
      await _home(tester);
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Trip next'));
      expect(tester.takeException(), isNull);
    });
  });

  group('recent activity (spec UC-5)', () {
    final row = find.byKey(const ValueKey('recent-activity'));

    testWidgets('the newest event across current and upcoming trips', (
      tester,
    ) async {
      await _home(
        tester,
        activity: {
          'newer': [_joined('a', 'ben', DateTime(2026, 10, 20))],
          'next': [_joined('b', 'ari', DateTime(2026, 10, 28))],
          'old': [_joined('c', 'ben', DateTime(2026, 10, 29))],
        },
      );
      await _scrollTo(tester, row);
      expect(
        find.descendant(of: row, matching: find.text('You joined the squad')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('🎒 Trip next')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byType(PersonAvatar)),
        findsOneWidget,
      );

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(ActivityScreen), findsOneWidget);
      expect(
        tester.widget<ActivityScreen>(find.byType(ActivityScreen)).adventureId,
        'next',
      );
    });

    testWidgets('reads one record per trip, and none for past trips', (
      tester,
    ) async {
      final service = await _home(
        tester,
        adventures: [_newer, _older, _next, _old],
        activity: {
          'newer': [_joined('a', 'ben', DateTime(2026, 10, 20))],
        },
      );
      expect(service.latestReads.toSet(), {'newer', 'older', 'next'});
      expect(service.recentReads, 0);
    });

    testWidgets('something just logged counts as newest', (tester) async {
      await _home(
        tester,
        activity: {
          'newer': [_joined('a', 'ben', DateTime(2026, 10, 28))],
          'next': [_joined('b', 'ari', null)],
        },
      );
      await _scrollTo(tester, row);
      expect(
        find.descendant(of: row, matching: find.text('You joined the squad')),
        findsOneWidget,
      );
    });

    testWidgets('a tab this person can’t read stays nameless', (tester) async {
      await _home(
        tester,
        activity: {
          'newer': [
            ActivityEntry(
              id: 'a',
              type: 'tab_deleted',
              actorUid: 'ben',
              subject: 'private-tab',
              createdAt: DateTime(2026, 10, 28),
            ),
          ],
        },
      );
      await _scrollTo(tester, row);
      expect(
        find.descendant(of: row, matching: find.text('Ben Roy deleted a tab')),
        findsOneWidget,
      );
    });

    testWidgets('no activity: no row', (tester) async {
      await _home(tester);
      expect(row, findsNothing);
      expect(find.text('Recent activity'), findsNothing);
    });

    testWidgets('a kind this version doesn’t know shows no row', (
      tester,
    ) async {
      await _home(
        tester,
        activity: {
          'newer': [
            ActivityEntry(
              id: 'a',
              type: 'from_the_future',
              actorUid: 'ben',
              subject: 'x',
              createdAt: DateTime(2026, 10, 28),
            ),
          ],
        },
      );
      expect(row, findsNothing);
    });

    testWidgets('nothing ahead: no row', (tester) async {
      await _home(
        tester,
        adventures: [_old],
        activity: {
          'old': [_joined('a', 'ben', DateTime(2026, 10, 28))],
        },
      );
      expect(row, findsNothing);
    });
  });
}
