import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_format.dart';
import 'package:roamio/features/budget/data/budget_service.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

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

/// Already over, by the test clock (29 Oct 2026).
final _ended = Adventure(
  id: 'bkk',
  name: 'Goa trip',
  countryCode: 'IN',
  startDate: DateTime(2026, 9),
  endDate: DateTime(2026, 9, 10),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari', 'ben'],
);

/// ₹1,200 taxi still waiting; Ari's share would be ₹600.
final _waitingTaxi = TabEntry(
  id: 't2',
  description: 'Taxi',
  category: 'local_transportation',
  date: DateTime(2026, 10, 27),
  createdBy: 'ben',
  status: TabStatus.waiting,
  split: TabSplit(
    amount: Money(120000, 'INR'),
    payers: const [Payment('ben', 120000)],
    participants: const ['ari', 'ben'],
    fxDate: '2026-10-27',
  ),
);

Future<FakeBudgetService> _openSplit(
  WidgetTester tester, {
  Adventure? adventure,
  List<TabEntry>? tabs,
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
    adventures: FakeAdventureService([adventure ?? _goa]),
    tabs: FakeTabService(tabs ?? [_dinner]),
    budgets: service,
    profileCurrency: currency,
    fx: FakeFxRepository(rates),
  );
  if (split) {
    await tester.tap(find.text('Split'));
    await tester.pumpAndSettle();
    if (adventure != null) {
      await tester.tap(find.widgetWithText(ChoiceChip, adventure.name));
      await tester.pumpAndSettle();
    }
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

    testWidgets('tap the widget to change it', (tester) async {
      final s = await _openSplit(
        tester,
        budgets: const {'bkk': Budget(amountMinor: 1000000, currency: 'INR')},
      );
      await _tap(tester, find.text('Your budget'));
      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Budget'),
      );
      expect(field.controller!.text, '10000.00');
      await tester.enterText(find.widgetWithText(TextField, 'Budget'), '2000');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save budget'));
      await tester.pumpAndSettle();
      expect(s.calls.last, 'set:bkk/200000 INR');
      expect(find.text('₹1,500.00 of ₹2,000.00 used · 75%'), findsOneWidget);
    });

    testWidgets('Remove asks first; Cancel keeps it', (tester) async {
      final s = await _openSplit(
        tester,
        budgets: const {'bkk': Budget(amountMinor: 1000000, currency: 'INR')},
      );
      await _tap(tester, find.text('Your budget'));
      await _tap(tester, find.text('Remove budget'));
      expect(find.text('Remove your budget?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(s.calls, isEmpty);
      expect(find.widgetWithText(PrimaryButton, 'Save budget'), findsOneWidget);

      await _tap(tester, find.text('Remove budget'));
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(s.calls, ['remove:bkk']);
      expect(find.text('Set a budget'), findsOneWidget);
    });

    testWidgets('a new budget has nothing to remove', (tester) async {
      await _openSplit(tester);
      await _tap(tester, find.text('Set a budget'));
      expect(find.text('Remove budget'), findsNothing);
    });

    testWidgets('says what’s left', (tester) async {
      await _openSplit(
        tester,
        budgets: const {'bkk': Budget(amountMinor: 1000000, currency: 'INR')},
      );
      expect(find.text('₹8,500.00 left'), findsOneWidget);
      expect(find.textContaining('over budget'), findsNothing);
    });

    testWidgets('says how far over', (tester) async {
      await _openSplit(
        tester,
        budgets: const {'bkk': Budget(amountMinor: 100000, currency: 'INR')},
      );
      expect(find.text('₹500.00 over budget'), findsOneWidget);
      expect(find.textContaining(RegExp('₹.* left')), findsNothing);
    });

    testWidgets('exactly on budget reads as nothing left', (tester) async {
      await _openSplit(
        tester,
        budgets: const {'bkk': Budget(amountMinor: 150000, currency: 'INR')},
      );
      expect(find.text('₹0.00 left'), findsOneWidget);
    });

    testWidgets('waiting tabs aren’t counted, and it says so', (tester) async {
      await _openSplit(
        tester,
        budgets: const {'bkk': Budget(amountMinor: 1000000, currency: 'INR')},
        tabs: [_dinner, _waitingTaxi],
      );
      expect(find.text('₹1,500.00 of ₹10,000.00 used · 15%'), findsOneWidget);
      expect(
        find.text('₹600.00 waiting for approval, not counted'),
        findsOneWidget,
      );
    });

    testWidgets('no waiting line with nothing waiting', (tester) async {
      await _openSplit(
        tester,
        budgets: const {'bkk': Budget(amountMinor: 1000000, currency: 'INR')},
      );
      expect(find.textContaining('waiting for approval'), findsNothing);
    });

    testWidgets('days left show during the trip', (tester) async {
      // Today in tests is 29 Oct 2026; the trip ends 2 Nov.
      await _openSplit(
        tester,
        budgets: const {'bkk': Budget(amountMinor: 1000000, currency: 'INR')},
      );
      expect(find.text('4 days left'), findsOneWidget);
    });

    testWidgets('days left don’t show outside the trip', (tester) async {
      await _openSplit(
        tester,
        adventure: _ended,
        budgets: const {'bkk': Budget(amountMinor: 1000000, currency: 'INR')},
      );
      expect(find.textContaining('days left'), findsNothing);
    });

    testWidgets('editable after the trip has ended', (tester) async {
      final s = await _openSplit(
        tester,
        adventure: _ended,
        budgets: const {'bkk': Budget(amountMinor: 1000000, currency: 'INR')},
      );
      await _tap(tester, find.text('Your budget'));
      await tester.enterText(find.widgetWithText(TextField, 'Budget'), '2000');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save budget'));
      await tester.pumpAndSettle();
      expect(s.calls.last, 'set:bkk/200000 INR');
    });

    test('days left wording', () {
      expect(daysLeftLabel(_goa, DateTime(2026, 11, 2)), 'Last day');
      expect(daysLeftLabel(_goa, DateTime(2026, 11)), '1 day left');
      expect(daysLeftLabel(_goa, DateTime(2026, 10, 20)), '13 days left');
      expect(daysLeftLabel(_goa, DateTime(2026, 10, 19)), isNull);
      expect(daysLeftLabel(_goa, DateTime(2026, 11, 3)), isNull);
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
