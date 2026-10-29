import 'dart:async';

import 'package:roamio/features/budget/data/budget_service.dart';

/// In-memory [BudgetService]: one budget per adventure, plus alerts.
class FakeBudgetService implements BudgetService {
  new({Map<String, Budget>? budgets, List<BudgetAlert>? alerts})
    : budgets = {...?budgets},
      _alerts = [...?alerts];

  final Map<String, Budget> budgets;
  final List<BudgetAlert> _alerts;
  final List<String> calls = [];
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<Budget?> budget(String adventureId) async* {
    yield budgets[adventureId];
    yield* _changes.stream.map((_) => budgets[adventureId]);
  }

  @override
  Future<void> set(String adventureId, Budget budget) async {
    calls.add('set:$adventureId/${budget.amountMinor} ${budget.currency}');
    budgets[adventureId] = budget;
    _changes.add(null);
  }

  @override
  Future<void> remove(String adventureId) async {
    calls.add('remove:$adventureId');
    budgets.remove(adventureId);
    _changes.add(null);
  }

  @override
  Stream<List<BudgetAlert>> alerts() async* {
    yield [..._alerts];
    yield* _changes.stream.map((_) => [..._alerts]);
  }

  @override
  Future<void> dismiss(String alertId) async {
    calls.add('dismiss:$alertId');
    _alerts.removeWhere((a) => a.id == alertId);
    _changes.add(null);
  }
}
