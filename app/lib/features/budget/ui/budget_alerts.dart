import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/features/budget/data/budget_service.dart';

/// Budget alerts on Home (spec UC-20): "You've used 80% of your Goa trip
/// budget". Each opens the Split tab or can be dismissed.
class BudgetAlerts extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(budgetAlertsProvider).value ?? const [];
    if (alerts.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in alerts)
          Card(
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
                    onPressed: () => context.go('/split'),
                    child: const Text('See split'),
                  ),
                  IconButton(
                    tooltip: 'Dismiss budget alert',
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        ref.read(budgetServiceProvider).dismiss(a.id),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
