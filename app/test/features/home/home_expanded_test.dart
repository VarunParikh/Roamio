import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/data/activity_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/activity_screen.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/budget/data/budget_service.dart';
import 'package:roamio/features/home/data/home_card_memory.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/splits/ui/split_screen.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/squad/ui/squad_section.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';

import '../../support/fake_activity_service.dart';
import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_budget_service.dart';
import '../../support/fake_home_card_memory.dart';
import '../../support/fake_squad_service.dart';
import '../../support/fake_tab_service.dart';

/// "Today" is 29 Oct 2026 in pumpRoamio; the tab fake keeps tabs under `bkk`.
Adventure _trip({DateTime? start, DateTime? end}) => Adventure(
  id: 'bkk',
  name: 'Goa trip',
  countryCode: 'IN',
  startDate: start ?? DateTime(2026, 10, 25),
  endDate: end ?? DateTime(2026, 11, 3),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari', 'ben'],
);

TabEntry _tab(int day, int minor, {int month = 10}) => TabEntry(
  id: 't$month-$day',
  description: 'Dinner',
  category: 'food_dining',
  date: DateTime(2026, month, day),
  createdBy: 'ari',
  split: TabSplit(
    amount: Money(minor, 'INR'),
    payers: [Payment('ari', minor)],
    participants: const ['ari', 'ben'],
    fxDate:
        '2026-${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}',
  ),
);

class _CountingTabs extends FakeTabService {
  new(super.initial);

  int reads = 0;

  @override
  Stream<List<TabEntry>> tabs(String adventureId, {required bool isAdmin}) {
    reads++;
    return super.tabs(adventureId, isAdmin: isAdmin);
  }
}

Future<void> _home(
  WidgetTester tester, {
  Adventure? adventure,
  List<TabEntry>? tabs,
  FakeTabService? tabService,
  FakeHomeCardMemory? memory,
  FakeActivityService? activity,
  FakeBudgetService? budgets,
  bool expand = true,
}) async {
  await pumpRoamio(
    tester,
    FakeAuthService(
      initial: const SessionFacts(
        uid: 'ari',
        hasAccount: true,
        ageStatus: 'adult',
      ),
    ),
    adventures: FakeAdventureService([adventure ?? _trip()]),
    tabs: tabService ?? FakeTabService(tabs ?? [_tab(27, 300000)]),
    homeCardMemory: memory,
    activity: activity,
    budgets: budgets,
    squad: FakeSquadService()
      ..names.addAll({'ari': 'Ari Chen', 'ben': 'Ben Roy'})
      ..palsByAdventure['bkk'] = [const Pal(id: 'kiko', nickname: 'Kiko')],
  );
  if (expand) await _tap(tester, find.byTooltip('Show details'));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('expanding (spec UC-5)', () {
    testWidgets('starts collapsed; the arrow opens and closes it', (
      tester,
    ) async {
      await _home(tester, expand: false);
      expect(find.text('Daily spend'), findsNothing);
      await _tap(tester, find.byTooltip('Show details'));
      expect(find.text('Daily spend'), findsOneWidget);
      await _tap(tester, find.byTooltip('Hide details'));
      expect(find.text('Daily spend'), findsNothing);
    });

    testWidgets('the phone remembers', (tester) async {
      final memory = FakeHomeCardMemory();
      await _home(tester, memory: memory);
      expect(memory.expanded, isTrue);
      await _tap(tester, find.byTooltip('Hide details'));
      expect(memory.expanded, isFalse);
    });

    testWidgets('opens expanded when it was left that way', (tester) async {
      await _home(
        tester,
        memory: FakeHomeCardMemory(expanded: true),
        expand: false,
      );
      expect(find.text('Daily spend'), findsOneWidget);
    });

    testWidgets('tabs load only when expanded', (tester) async {
      final tabs = _CountingTabs([_tab(27, 300000)]);
      await _home(tester, tabService: tabs, expand: false);
      expect(tabs.reads, 0);
      await _tap(tester, find.byTooltip('Show details'));
      expect(tabs.reads, greaterThan(0));
    });
  });

  group('what it shows (spec UC-5)', () {
    testWidgets('your budget, with no budget a plain Set a budget', (
      tester,
    ) async {
      await _home(tester);
      expect(find.text('Set a budget'), findsOneWidget);
    });

    testWidgets('your budget when there is one', (tester) async {
      await _home(
        tester,
        budgets: FakeBudgetService(
          budgets: const {'bkk': Budget(amountMinor: 1000000, currency: 'INR')},
        ),
      );
      // ₹1,500 of ₹10,000.
      expect(find.text('₹8,500.00 left'), findsOneWidget);
    });

    testWidgets('daily spend: today stands out in blue and says its amount', (
      tester,
    ) async {
      await _home(tester, tabs: [_tab(27, 300000), _tab(29, 50000)]);
      expect(find.text('Today · ₹500.00'), findsOneWidget);
      expect(find.byKey(const ValueKey('day-2026-10-29')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-2026-10-28')), findsOneWidget);
      Color? barColor(String day) {
        final bar = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(ValueKey('day-$day')),
                matching: find.byType(Container),
              )
              .first,
        );
        return (bar.decoration! as BoxDecoration).color;
      }

      expect(barColor('2026-10-29'), RoamioColors.cobalt);
      expect(barColor('2026-10-27'), RoamioColors.muted);
    });

    testWidgets('a short trip has fewer bars', (tester) async {
      await _home(
        tester,
        adventure: _trip(start: DateTime(2026, 10, 28)),
        tabs: [_tab(28, 300000)],
      );
      expect(find.byKey(const ValueKey('day-2026-10-29')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-2026-10-28')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-2026-10-27')), findsNothing);
    });

    testWidgets('a long trip shows about 7 days and swipes to earlier ones', (
      tester,
    ) async {
      await _home(
        tester,
        adventure: _trip(start: DateTime(2026, 9, 25)),
        tabs: [_tab(27, 100000, month: 9), _tab(29, 100000)],
      );
      expect(find.byKey(const ValueKey('day-2026-10-29')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-2026-09-27')), findsNothing);
      // Each bar's slot is a seventh of the chart's width.
      final chart = find.byKey(const ValueKey('day-bars'));
      final slot = tester.getSize(find.byKey(const ValueKey('day-2026-10-29')));
      expect(tester.getSize(chart).width / slot.width, closeTo(7, 0.01));

      await tester.drag(chart, const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('day-2026-10-29')), findsNothing);
    });

    testWidgets('no tabs: No spending yet', (tester) async {
      await _home(tester, tabs: const []);
      expect(find.text('No spending yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('day-bars')), findsNothing);
    });

    testWidgets('before the trip there’s no chart', (tester) async {
      await _home(
        tester,
        adventure: _trip(
          start: DateTime(2026, 11, 10),
          end: DateTime(2026, 11, 12),
        ),
        tabs: const [],
      );
      expect(find.text('Daily spend'), findsNothing);
      expect(find.text('No spending yet'), findsNothing);
      expect(find.text('See split'), findsOneWidget);
    });

    testWidgets('fits a small phone', (tester) async {
      await _home(tester);
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('links (spec UC-5)', () {
    Future<void> expectSplitOnTrip(WidgetTester tester) async {
      expect(find.byType(SplitScreen), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Goa trip'))
            .selected,
        isTrue,
      );
    }

    testWidgets('See split opens Split on this adventure', (tester) async {
      await _home(tester);
      await _tap(tester, find.text('See split'));
      await expectSplitOnTrip(tester);
    });

    testWidgets('View all opens Split on this adventure', (tester) async {
      await _home(tester);
      await _tap(tester, find.text('View all'));
      await expectSplitOnTrip(tester);
    });

    testWidgets('the squad row opens the squad, with pals', (tester) async {
      await _home(tester);
      await _tap(tester, find.byKey(const ValueKey('hero-squad')));
      expect(find.byType(SquadSection), findsOneWidget);
      expect(find.text('Kiko'), findsOneWidget);
    });

    testWidgets('recent activity shows the latest and opens Activity', (
      tester,
    ) async {
      await _home(
        tester,
        activity: FakeActivityService({
          'bkk': [
            ActivityEntry(
              id: 'a2',
              type: 'member_joined',
              actorUid: 'ben',
              subject: 'ben',
              createdAt: DateTime(2026, 10, 28),
            ),
            ActivityEntry(
              id: 'a1',
              type: 'settlement_recorded',
              actorUid: 'ari',
              subject: 'p1',
              createdAt: DateTime(2026, 10, 27),
            ),
          ],
        }),
      );
      final row = find.byKey(const ValueKey('hero-activity'));
      expect(
        find.descendant(
          of: row,
          matching: find.text('Ben Roy joined the squad'),
        ),
        findsOneWidget,
      );
      expect(find.text('You recorded a payment'), findsNothing);
      await _tap(tester, row);
      expect(find.byType(ActivityScreen), findsOneWidget);
    });

    testWidgets('no activity: no row', (tester) async {
      await _home(tester);
      expect(find.byKey(const ValueKey('hero-activity')), findsNothing);
    });
  });

  group('FileHomeCardMemory', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('roamio'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('remembers, and a first time or a bad file is collapsed', () async {
      final memory = FileHomeCardMemory(folder: () async => dir);
      expect(await memory.readExpanded(), isFalse);
      await memory.writeExpanded(expanded: true);
      expect(await memory.readExpanded(), isTrue);

      File('${dir.path}/home_card.json').writeAsStringSync('not json');
      expect(await memory.readExpanded(), isFalse);
    });
  });
}
