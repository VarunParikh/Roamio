import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/ui/bottom_bar.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/budget/data/budget_service.dart';
import 'package:roamio/features/home/ui/home_screen.dart';
import 'package:roamio/features/splits/ui/split_screen.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_budget_service.dart';
import '../../support/fake_tab_service.dart';

/// Today is 29 Oct 2026: Goa is happening now, Bali is coming up.
Adventure _trip(String id, String name, DateTime start, DateTime end) =>
    Adventure(
      id: id,
      name: name,
      countryCode: 'IN',
      startDate: start,
      endDate: end,
      baseCurrency: 'INR',

      leaderUid: 'ari',
      memberUids: const ['ari', 'ben'],
    );

final Adventure _goa = _trip(
  'goa',
  'Goa trip',
  DateTime(2026, 10, 20),
  DateTime(2026, 11, 2),
);
final Adventure _bali = _trip(
  'bali',
  'Bali trip',
  DateTime(2026, 12, 3),
  DateTime(2026, 12, 9),
);

const BudgetAlert _baliAlert = BudgetAlert(
  id: 'bali_budget_80',
  adventureId: 'bali',
  adventureName: 'Bali trip',
  threshold: 80,
);

Future<void> _open(
  WidgetTester tester, {
  List<BudgetAlert> alerts = const [],
}) => pumpRoamio(
  tester,
  FakeAuthService(initial: readyFacts),
  adventures: FakeAdventureService([_goa, _bali]),
  tabs: FakeTabService(),
  budgets: FakeBudgetService(alerts: alerts),
);

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first));

Future<void> _go(WidgetTester tester, String location) async {
  _router(tester).go(location);
  await tester.pumpAndSettle();
}

bool _chipSelected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

void _expectSplitOn(WidgetTester tester, String label) {
  expect(find.byType(SplitScreen), findsOneWidget);
  for (final l in ['Overall', 'Goa trip', 'Bali trip']) {
    expect(_chipSelected(tester, l), l == label, reason: l);
  }
}

void main() {
  group('Open Split on an adventure (spec UC-5, UC-20)', () {
    testWidgets('/split?adventure=<id> opens that adventure, Split tab on', (
      tester,
    ) async {
      await _open(tester);
      await _go(tester, '/split?adventure=bali');

      _expectSplitOn(tester, 'Bali trip');
      final bar = find.descendant(
        of: find.byType(RoamioBottomBar),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Split',
        ),
      );
      expect(tester.widget<Semantics>(bar).properties.selected, isTrue);
    });

    testWidgets('the budget alert’s See split opens its own adventure', (
      tester,
    ) async {
      await _open(tester, alerts: const [_baliAlert]);
      // Home defaults to Goa, so the old plain /split was the wrong place.
      await tester.tap(find.text('See split'));
      await tester.pumpAndSettle();

      _expectSplitOn(tester, 'Bali trip');
    });

    testWidgets('opening another adventure while Split shows switches', (
      tester,
    ) async {
      await _open(tester);
      await _go(tester, '/split?adventure=bali');
      await _go(tester, '/split?adventure=goa');
      _expectSplitOn(tester, 'Goa trip');
    });

    testWidgets('opening the same adventure again after picking another chip '
        'still switches back', (tester) async {
      await _open(tester, alerts: const [_baliAlert]);
      await tester.tap(find.text('See split'));
      await tester.pumpAndSettle();
      final goa = find.widgetWithText(ChoiceChip, 'Goa trip');
      await tester.ensureVisible(goa);
      await tester.tap(goa);
      await tester.pumpAndSettle();
      _expectSplitOn(tester, 'Goa trip');

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.tap(find.text('See split'));
      await tester.pumpAndSettle();
      _expectSplitOn(tester, 'Bali trip');
    });

    testWidgets('the Split tab still opens the active adventure and chips '
        'still work', (tester) async {
      await _open(tester);
      await tester.tap(find.text('Split'));
      await tester.pumpAndSettle();
      _expectSplitOn(tester, 'Goa trip');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Overall'));
      await tester.pumpAndSettle();
      _expectSplitOn(tester, 'Overall');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Bali trip'));
      await tester.pumpAndSettle();
      _expectSplitOn(tester, 'Bali trip');
    });

    testWidgets('an unknown id falls back to the default', (tester) async {
      await _open(tester);
      await _go(tester, '/split?adventure=gone');
      _expectSplitOn(tester, 'Goa trip');
    });

    testWidgets('an unknown id with nothing active falls back to Overall', (
      tester,
    ) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_bali]),
        tabs: FakeTabService(),
      );
      await _go(tester, '/split?adventure=gone');
      expect(_chipSelected(tester, 'Overall'), isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
