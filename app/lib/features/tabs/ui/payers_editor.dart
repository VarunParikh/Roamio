import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/splits/domain/money.dart';

/// "Split payment" (spec UC-21): what each member paid. Pals never pay.
/// A live counter shows how much of the tab is covered.
class PayersEditor extends StatelessWidget {
  const new({
    required this.fields,
    required this.labels,
    required this.currency,
    required this.amountMinor,
    required this.symbol,
    required this.onChanged,
    super.key,
  });

  /// One amount field per member id, in squad order.
  final Map<String, TextEditingController> fields;
  final Map<String, String> labels;
  final String currency;
  final int amountMinor;
  final String? symbol;
  final VoidCallback onChanged;

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
        for (final MapEntry(key: id, value: field) in fields.entries)
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
        Text(
          '${money(assigned)} of ${money(amountMinor)} assigned',
          style: text.bodyMedium?.copyWith(
            color: ok ? RoamioColors.mint : RoamioColors.coral,
          ),
        ),
      ],
    );
  }
}
