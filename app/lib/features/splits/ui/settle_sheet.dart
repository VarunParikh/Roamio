import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/tabs/domain/tab_list.dart';

/// "Mark as settled" (spec UC-26a): how much [title]'s payment was, in the
/// trip's [currency]. Starts at [suggestedMinor]; can be lowered for a part
/// payment, never raised. Returns the amount, or null if dismissed.
Future<int?> showSettleSheet(
  BuildContext context, {
  required String title,
  required int suggestedMinor,
  required String currency,
  required String? symbol,
  required Widget people,
}) => showModalBottomSheet<int>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _SettleSheet(
    title: title,
    suggestedMinor: suggestedMinor,
    currency: currency,
    symbol: symbol,
    people: people,
  ),
);

class _SettleSheet extends StatefulWidget {
  const new({
    required this.title,
    required this.suggestedMinor,
    required this.currency,
    required this.symbol,
    required this.people,
  });

  final String title;
  final int suggestedMinor;
  final String currency;
  final String? symbol;

  /// Who is paying whom, with their pictures (spec UC-28a).
  final Widget people;

  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  late final _amount = TextEditingController(
    text: amountText(widget.suggestedMinor, widget.currency),
  );
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String get _max => formatMoney(
    Money(widget.suggestedMinor, widget.currency),
    symbol: widget.symbol,
  );

  void _save() {
    final minor = parseAmount(_amount.text, widget.currency);
    setState(
      () => _error = minor == null || minor <= 0
          ? 'Enter an amount above zero.'
          : minor > widget.suggestedMinor
          ? 'Up to $_max.'
          : null,
    );
    if (_error == null) Navigator.pop(context, minor);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
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
          Text('Mark as settled', style: text.headlineSmall),
          const SizedBox(height: 12),
          widget.people,
          const SizedBox(height: 12),
          Text(
            '${widget.title} outside the app. No money moves in Roamio; '
            'this just records it.',
            style: text.bodyMedium?.copyWith(color: RoamioColors.slate),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              LengthLimitingTextInputFormatter(16),
            ],
            decoration: InputDecoration(
              labelText: 'Amount paid',
              suffixText: widget.currency,
              helperText: 'Up to $_max. Lower it for a part payment.',
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Mark as settled', onPressed: _save),
        ],
      ),
    );
  }
}
