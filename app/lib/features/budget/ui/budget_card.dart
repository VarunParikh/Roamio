import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
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

    Widget body;
    if (b == null) {
      body = Row(
        children: [
          Expanded(child: Text('Only you can see your budget.', style: slate)),
          TextButton(
            onPressed: () => _edit(context, ref, null),
            child: const Text('Set a budget'),
          ),
        ],
      );
    } else {
      final report = ref
          .watch(reportInProvider((adventure.id, b.currency)))
          .value;
      final measurable = report != null && report.currency == b.currency;
      final used = measurable ? report.myShare : 0;
      final percent = b.amountMinor == 0 ? 0 : used * 100 ~/ b.amountMinor;
      String money(int m) => formatWithSymbol(ref, Money(m, b.currency));
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Your budget', style: text.titleMedium)),
              TextButton(
                onPressed: () => _edit(context, ref, b),
                child: const Text('Change'),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(budgetServiceProvider).remove(adventure.id),
                child: const Text('Remove'),
              ),
            ],
          ),
          if (report == null)
            const LinearProgressIndicator()
          else if (!measurable)
            Text(
              'Can’t measure yet: exchange rates aren’t available.',
              style: slate,
            )
          else ...[
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
          ],
          const SizedBox(height: 4),
          Text('Only you can see your budget.', style: text.bodySmall),
        ],
      );
    }
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: body),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Budget? current,
  ) async {
    final currencies =
        ref.read(countriesProvider).value?.currencies ?? const <String>[];
    final picked = await showModalBottomSheet<Budget>(
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
    if (picked != null) {
      await ref.read(budgetServiceProvider).set(adventure.id, picked);
    }
  }
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
    Navigator.pop(context, Budget(amountMinor: minor, currency: _currency));
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
      ],
    ),
  );
}
