import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/domain/new_tab.dart';

/// Custom % (spec UC-21): each participant's share, with a live
/// "x% of 100% assigned" counter. Save waits until it is exactly 100%.
class PercentEditor extends StatelessWidget {
  const new({
    required this.fields,
    required this.labels,
    required this.onChanged,
    super.key,
  });

  /// One percentage field per participant id, in list order.
  final Map<String, TextEditingController> fields;
  final Map<String, String> labels;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final assigned = fields.values.fold(
      0,
      (sum, f) => sum + (parsePercent(f.text) ?? 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final MapEntry(key: id, value: field) in fields.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              key: ValueKey('pct-$id'),
              controller: field,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: labels[id],
                suffixText: '%',
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        Text(
          '${formatBasisPoints(assigned)} of 100% assigned',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: assigned == fullBasisPoints
                ? RoamioColors.mint
                : RoamioColors.coral,
          ),
        ),
      ],
    );
  }
}
