import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/tabs/domain/payment_method.dart';

/// Paid with for one payer (spec UC-21). Empty until there's a method.
class PaidWithDropdown extends StatelessWidget {
  const new({
    required this.payerId,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String payerId;
  final PaymentMethod? value;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<PaymentMethod>(
    key: ValueKey('method-$payerId'),
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Paid with'),
    items: [
      for (final m in PaymentMethod.values)
        DropdownMenuItem(
          value: m,
          child: Text('${m.emoji} ${m.label}', semanticsLabel: m.label),
        ),
    ],
    onChanged: (m) {
      if (m != null) onChanged(m);
    },
  );
}

/// "Split payment" (spec UC-21): what each member paid and how. Pals never
/// pay. A live counter shows how much of the tab is covered.
class PayersEditor extends StatelessWidget {
  const new({
    required this.fields,
    required this.labels,
    required this.currency,
    required this.amountMinor,
    required this.symbol,
    required this.onChanged,
    required this.methodOf,
    required this.onMethod,
    super.key,
  });

  /// One amount field per member id, in squad order.
  final Map<String, TextEditingController> fields;
  final Map<String, String> labels;
  final String currency;
  final int amountMinor;
  final String? symbol;
  final VoidCallback onChanged;
  final PaymentMethod? Function(String id) methodOf;
  final void Function(String id, PaymentMethod method) onMethod;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final assigned = fields.values.fold(
      0,
      (sum, f) => sum + (parseAmount(f.text, currency) ?? 0),
    );
    String money(int m) => formatMoney(Money(m, currency), symbol: symbol);
    final ok = assigned == amountMinor && amountMinor > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final MapEntry(key: id, value: field) in fields.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              key: ValueKey('pay-$id'),
              controller: field,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                LengthLimitingTextInputFormatter(16),
              ],
              decoration: InputDecoration(
                labelText: labels[id],
                suffixText: currency,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          // Only someone who paid something has a method to choose.
          if ((parseAmount(field.text, currency) ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PaidWithDropdown(
                payerId: id,
                value: methodOf(id),
                onChanged: (m) => onMethod(id, m),
              ),
            ),
        ],
        Text(
          '${money(assigned)} of ${money(amountMinor)} assigned',
          style: text.bodyMedium?.copyWith(
            color: ok ? RoamioColors.mintText : RoamioColors.coralText,
          ),
        ),
      ],
    );
  }
}
