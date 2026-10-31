import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/router/app_router.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/budget/ui/budget_widget.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_fx_repository.dart';
import '../../support/fake_home_card_memory.dart';
import '../../support/fake_tab_service.dart';

/// What the owner's first test on a phone turned up (2026-10-31). "Today" is
/// 29 Oct 2026 in pumpRoamio.
final Adventure _soon = Adventure(
  id: 'bkk',
  name: 'Thailand',
  countryCode: 'IN',
  startDate: DateTime(2026, 11, 3),
  endDate: DateTime(2026, 11, 13),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari'],
);

final TabEntry _personal = TabEntry(
  id: 'p',
  description: 'Currency exchange',
  category: 'incidentals',
  date: DateTime(2026, 10, 29),
  createdBy: 'ari',
  status: TabStatus.personal,
  split: TabSplit(
    amount: Money(100000, 'INR'),
    payers: const [Payment('ari', 100000)],
    participants: const ['ari'],
    fxDate: '2026-10-29',
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  List<TabEntry> tabs = const [],
  Adventure? adventure,
  bool expanded = false,
  Map<String, String> rates = const {},
  String currency = 'INR',
}) => pumpRoamio(
  tester,
  FakeAuthService(
    initial: const SessionFacts(
      uid: 'ari',
      hasAccount: true,
      ageStatus: 'adult',
    ),
  ),
  adventures: FakeAdventureService([adventure ?? _soon]),
  tabs: FakeTabService(tabs),
  homeCardMemory: FakeHomeCardMemory(expanded: expanded),
  fx: FakeFxRepository(rates),
  profileCurrency: currency,
);

Future<void> _go(WidgetTester tester, String location) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an expanded card shows a tab added before the trip', (
    tester,
  ) async {
    await _pump(tester, tabs: [_personal], expanded: true);
    expect(find.text('Daily spend'), findsOneWidget);
    expect(find.text('Today · ₹1,000.00'), findsOneWidget);
  });

  testWidgets('the adventure page has the budget', (tester) async {
    await _pump(tester);
    await _go(tester, '/adventures/bkk');
    expect(find.byType(BudgetWidget), findsOneWidget);
    expect(find.text('Set a budget'), findsOneWidget);
  });

  testWidgets('only personal tabs: your own charts on Split', (tester) async {
    await _pump(tester, tabs: [_personal]);
    await _go(tester, Routes.splitFor('bkk'));
    expect(find.text('Your spend by category'), findsOneWidget);
    expect(find.text('Your spend ₹1,000.00'), findsOneWidget);
    expect(find.text('Who pays whom'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Your spend by day'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Your spend by day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Overall says when rates hold the total back, not ₹0', (
    tester,
  ) async {
    await _pump(tester, tabs: [_personal], adventure: _soon, currency: 'THB');
    await _go(tester, '/split');
    expect(find.text('Not available yet'), findsOneWidget);
    expect(find.textContaining('exchange rates'), findsOneWidget);
  });

  group('the switches', () {
    testWidgets('off is easy to see', (tester) async {
      await _pump(tester);
      final context = tester.element(find.byType(Scaffold).first);
      final theme = Theme.of(context).switchTheme;
      expect(theme.trackOutlineColor?.resolve({}), isNot(Colors.transparent));
      expect(
        theme.thumbColor?.resolve({}),
        isNot(theme.trackColor?.resolve({})),
      );
    });
  });

  group('Add tab’s categories', () {
    testWidgets('the common ones first, then View more and View less', (
      tester,
    ) async {
      await _pump(tester);
      await _go(tester, '/adventures/bkk/tabs/new');
      expect(find.textContaining('Food & Dining'), findsOneWidget);
      expect(find.textContaining('Miscellaneous'), findsNothing);

      final more = find.text('View more');
      await tester.scrollUntilVisible(
        more,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.textContaining('Miscellaneous'), findsOneWidget);

      // The one picked stays when folded.
      final misc = find.textContaining('Miscellaneous');
      await tester.ensureVisible(misc);
      await tester.pumpAndSettle();
      await tester.tap(misc);
      await tester.pumpAndSettle();
      final less = find.text('View less');
      await tester.scrollUntilVisible(
        less,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(less);
      await tester.pumpAndSettle();
      expect(find.textContaining('Miscellaneous'), findsOneWidget);
      expect(find.textContaining('Shopping'), findsNothing);
    });
  });
}
