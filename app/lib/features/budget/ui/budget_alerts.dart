import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/router/app_router.dart';
import 'package:roamio/features/budget/data/budget_service.dart';

/// Budget alerts for Needs you (spec UC-20): "You've used 80% of your Goa
/// trip budget". Each opens Split on its adventure or can be dismissed.
List<Widget> budgetAlertItems(BuildContext context, WidgetRef ref) {
  final alerts = ref.watch(budgetAlertsProvider).value ?? const [];
  final text = Theme.of(context).textTheme;
  return [
    for (final a in alerts)
      Card(
        key: ValueKey('budget-alert-${a.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  a.threshold >= 100
                      ? 'You’ve reached your ${a.adventureName} budget'
                      : 'You’ve used ${a.threshold}% of your '
                            '${a.adventureName} budget',
                  style: text.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => context.go(Routes.splitFor(a.adventureId)),
                child: const Text('See split'),
              ),
              IconButton(
                tooltip: 'Dismiss budget alert',
                icon: const Icon(Icons.close),
                onPressed: () => ref.read(budgetServiceProvider).dismiss(a.id),
              ),
            ],
          ),
        ),
      ),
  ];
}
