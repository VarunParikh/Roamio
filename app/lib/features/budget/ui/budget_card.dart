import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_format.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/budget/data/budget_service.dart';
import 'package:roamio/features/profile/data/profile_service.dart';
import 'package:roamio/features/splits/data/split_report_provider.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/tabs/domain/tab_list.dart';
import 'package:roamio/features/tabs/ui/tabs_section.dart';

/// Your private budget for an adventure (spec UC-19, UC-20): how much of
/// it your own share of the tabs has used. Alerts come from the server.
class BudgetCard extends ConsumerWidget {
  const new({required this.adventure, super.key});

  final Adventure adventure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final slate = text.bodyMedium?.copyWith(color: RoamioColors.slate);
    final budget = ref.watch(budgetProvider(adventure.id));
    if (!budget.hasValue) return const SizedBox.shrink();
    final b = budget.value;

    if (b == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text('Only you can see your budget.', style: slate),
              ),
              TextButton(
                onPressed: () => _edit(context, ref, null),
                child: const Text('Set a budget'),
              ),
            ],
          ),
        ),
      );
    }

    final report = ref
        .watch(reportInProvider((adventure.id, b.currency)))
        .value;
    final measurable = report != null && report.currency == b.currency;
    final used = measurable ? report.myShare : 0;
    final percent = b.amountMinor == 0 ? 0 : used * 100 ~/ b.amountMinor;
    final left = b.amountMinor - used;
    final waiting = measurable ? report.waitingMyShare : 0;
    final daysLeft = daysLeftLabel(adventure, ref.watch(todayProvider));
    String money(int m) => formatWithSymbol(ref, Money(m, b.currency));

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _edit(context, ref, b),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Your budget', style: text.titleMedium)),
                  const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: RoamioColors.slate,
                    semanticLabel: 'Change your budget',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (report == null)
                const LinearProgressIndicator()
              else if (!measurable)
                Text(
                  'Can’t measure yet: exchange rates aren’t available.',
                  style: slate,
                )
              else ...[
                Text(
                  left < 0
                      ? '${money(-left)} over budget'
                      : '${money(left)} left',
                  style: text.titleMedium?.copyWith(
                    color: left < 0
                        ? RoamioColors.coralText
                        : RoamioColors.mintText,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (percent / 100).clamp(0, 1).toDouble(),
                  color: percent >= 100 ? RoamioColors.coral : RoamioColors.ink,
                  backgroundColor: RoamioColors.hairline,
                ),
                const SizedBox(height: 6),
                Text(
                  '${money(used)} of ${money(b.amountMinor)} used · $percent%',
                  style: text.bodyMedium,
                ),
                if (waiting > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${money(waiting)} waiting for approval, not counted',
                    style: slate,
                  ),
                ],
              ],
              if (daysLeft != null) ...[
                const SizedBox(height: 2),
                Text(daysLeft, style: slate),
              ],
              const SizedBox(height: 4),
              Text('Only you can see your budget.', style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Budget? current,
  ) async {
    final currencies =
        ref.read(countriesProvider).value?.currencies ?? const <String>[];
    final picked = await showModalBottomSheet<_SheetResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BudgetSheet(
        current: current,
        defaultCurrency: ref.read(profileCurrencyProvider).value ?? 'INR',
        currencies: currencies,
      ),
    );
    final service = ref.read(budgetServiceProvider);
    switch (picked) {
      case _Save(:final budget):
        await service.set(adventure.id, budget);
      case _Remove():
        await service.remove(adventure.id);
      case null:
        return;
    }
  }
}

/// What the sheet was closed with.
sealed class _SheetResult {
  const new();
}

class _Save extends _SheetResult {
  const new(this.budget);

  final Budget budget;
}

class _Remove extends _SheetResult {
  const new();
}

class _BudgetSheet extends StatefulWidget {
  const new({
    required this.current,
    required this.defaultCurrency,
    required this.currencies,
  });

  final Budget? current;
  final String defaultCurrency;
  final List<String> currencies;

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late String _currency = widget.current?.currency ?? widget.defaultCurrency;
  late final _amount = TextEditingController(
    text: widget.current == null
        ? ''
        : amountText(widget.current!.amountMinor, widget.current!.currency),
  );
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final minor = parseAmount(_amount.text, _currency);
    if (minor == null || minor <= 0) {
      setState(() => _error = 'Enter an amount above zero.');
      return;
    }
    Navigator.pop(
      context,
      _Save(Budget(amountMinor: minor, currency: _currency)),
    );
  }

  Future<void> _remove() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove your budget?'),
        content: const Text('Your tabs stay as they are.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if ((sure ?? false) && mounted) {
      Navigator.pop(context, const _Remove());
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      0,
      16,
      16 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.current == null ? 'Set a budget' : 'Change your budget',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Measured against your own share of the tabs. We’ll let you know '
          'at 80% and 100%. Only you can see it.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: RoamioColors.slate),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  LengthLimitingTextInputFormatter(16),
                ],
                decoration: InputDecoration(
                  labelText: 'Budget',
                  errorText: _error,
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: [
                  for (final c in {_currency, ...widget.currencies})
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (c) => setState(() => _currency = c ?? _currency),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Save budget', onPressed: _save),
        if (widget.current != null)
          TextButton(onPressed: _remove, child: const Text('Remove budget')),
      ],
    ),
  );
}
