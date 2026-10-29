import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/budget/data/budget_service.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_budget_service.dart';
import '../../support/fake_fx_repository.dart';
import '../../support/fake_tab_service.dart';

final _goa = Adventure(
  id: 'bkk',
  name: 'Goa trip',
  countryCode: 'IN',
  startDate: DateTime(2026, 10, 20),
  endDate: DateTime(2026, 11, 2),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari', 'ben'],
);

/// ₹3,000 dinner; Ari's share is ₹1,500 (equal with Ben).
final _dinner = TabEntry(
  id: 't1',
  description: 'Dinner',
  category: 'food_dining',
  date: DateTime(2026, 10, 27),
  createdBy: 'ben',
  split: TabSplit(
    amount: Money(300000, 'INR'),
    payers: const [Payment('ben', 300000)],
    participants: const ['ari', 'ben'],
    fxDate: '2026-10-27',
  ),
);

Future<FakeBudgetService> _openSplit(
  WidgetTester tester, {
  Map<String, Budget>? budgets,
  List<BudgetAlert>? alerts,
  String currency = 'INR',
  Map<String, String> rates = const {},
  bool split = true,
}) async {
  final service = FakeBudgetService(budgets: budgets, alerts: alerts);
  await pumpRoamio(
    tester,
    FakeAuthService(initial: readyFacts),
    adventures: FakeAdventureService([_goa]),
    tabs: FakeTabService([_dinner]),
    budgets: service,
    profileCurrency: currency,
    fx: FakeFxRepository(rates),
  );
  if (split) {
    await tester.tap(find.text('Split'));
    await tester.pumpAndSettle();
  }
  return service;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('personal budget (spec UC-19, UC-20)', () {
    testWidgets('set a budget, private, in your currency by default', (
      tester,
    ) async {
      final s = await _openSplit(tester);
      expect(find.text('Only you can see your budget.'), findsOneWidget);

      await _tap(tester, find.text('Set a budget'));
      await tester.enterText(find.widgetWithText(TextField, 'Budget'), '10000');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save budget'));
      await tester.pumpAndSettle();

      expect(s.calls, ['set:bkk/1000000 INR']);
      expect(find.text('₹1,500.00 of ₹10,000.00 used · 15%'), findsOneWidget);
    });

    testWidgets('measured in the budget’s own currency', (tester) async {
      await _openSplit(
        tester,
        budgets: const {'bkk': Budget(amountMinor: 100000, currency: 'THB')},
        rates: const {'INR': '84', 'THB': '35'},
      );
      // Ari's ₹1,500 = ฿625.00.
      expect(find.text('฿625.00 of ฿1,000.00 used · 62%'), findsOneWidget);
    });

    testWidgets('says so when it can’t convert yet', (tester) async {
      await _openSplit(
        tester,
        budgets: const {'bkk': Budget(amountMinor: 100000, currency: 'THB')},
      );
      expect(
        find.text('Can’t measure yet: exchange rates aren’t available.'),
        findsOneWidget,
      );
    });

    testWidgets('can be changed or removed', (tester) async {
      final s = await _openSplit(
        tester,
        budgets: const {'bkk': Budget(amountMinor: 1000000, currency: 'INR')},
      );
      await _tap(tester, find.text('Change'));
      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Budget'),
      );
      expect(field.controller!.text, '10000.00');
      await tester.enterText(find.widgetWithText(TextField, 'Budget'), '2000');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save budget'));
      await tester.pumpAndSettle();
      expect(find.text('₹1,500.00 of ₹2,000.00 used · 75%'), findsOneWidget);

      await _tap(tester, find.text('Remove'));
      expect(s.calls.last, 'remove:bkk');
      expect(find.text('Set a budget'), findsOneWidget);
    });

    testWidgets('an empty budget is refused', (tester) async {
      final s = await _openSplit(tester);
      await _tap(tester, find.text('Set a budget'));
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save budget'));
      await tester.pumpAndSettle();
      expect(find.text('Enter an amount above zero.'), findsOneWidget);
      expect(s.calls, isEmpty);
    });

    testWidgets('alerts show on Home and can be dismissed', (tester) async {
      final s = await _openSplit(
        tester,
        split: false,
        alerts: const [
          BudgetAlert(
            id: 'bkk_budget_80',
            adventureId: 'bkk',
            adventureName: 'Goa trip',
            threshold: 80,
          ),
        ],
      );
      expect(
        find.text('You’ve used 80% of your Goa trip budget'),
        findsOneWidget,
      );
      await _tap(tester, find.byTooltip('Dismiss budget alert'));
      expect(s.calls, ['dismiss:bkk_budget_80']);
      expect(find.textContaining('of your Goa trip budget'), findsNothing);
    });
  });
}
