import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/settle_amount.dart';
import 'package:roamio/features/tabs/domain/tab_list.dart';

/// "Mark as settled" (spec UC-26a): how much [title]'s payment was. It starts
/// at [suggestedMinor] in the trip's [currency] and can be lowered for a part
/// payment, never raised. It can be typed in any currency in [currencies], and
/// shows what that comes to in [viewerCurrency]. Returns the amount in the
/// trip's currency, or null if dismissed.
Future<int?> showSettleSheet(
  BuildContext context, {
  required String title,
  required int suggestedMinor,
  required String currency,
  required Widget people,
  required String viewerCurrency,
  required Iterable<String> currencies,
  required FxRates? rates,
  required String? Function(String currency) symbolFor,
}) => showModalBottomSheet<int>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _SettleSheet(
    title: title,
    suggestedMinor: suggestedMinor,
    currency: currency,
    people: people,
    viewerCurrency: viewerCurrency,
    currencies: currencies,
    rates: rates,
    symbolFor: symbolFor,
  ),
);

class _SettleSheet extends StatefulWidget {
  const new({
    required this.title,
    required this.suggestedMinor,
    required this.currency,
    required this.people,
    required this.viewerCurrency,
    required this.currencies,
    required this.rates,
    required this.symbolFor,
  });

  final String title;
  final int suggestedMinor;
  final String currency;
  final String viewerCurrency;
  final Iterable<String> currencies;
  final FxRates? rates;
  final String? Function(String currency) symbolFor;

  /// Who is paying whom, with their pictures (spec UC-28a).
  final Widget people;

  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  /// How much of the screen the sheet's content fills, keyboard closed.
  static const _tallShare = 0.68;

  late String _typedIn = widget.currency;
  late final _amount = TextEditingController(
    text: amountText(widget.suggestedMinor, widget.currency),
  );
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _money(int minor, String currency) =>
      formatMoney(Money(minor, currency), symbol: widget.symbolFor(currency));

  /// The most that can be paid, in the currency being typed.
  int? get _maxHere => maxInCurrency(
    maxTripMinor: widget.suggestedMinor,
    currency: _typedIn,
    tripCurrency: widget.currency,
    rates: widget.rates,
  );

  /// The amount typed, as the trip's currency; null if unreadable or no rate.
  int? get _inTrip {
    final minor = parseAmount(_amount.text, _typedIn);
    if (minor == null) return null;
    return settledInTripCurrency(
      paidMinor: minor,
      currency: _typedIn,
      tripCurrency: widget.currency,
      maxTripMinor: widget.suggestedMinor,
      rates: widget.rates,
    );
  }

  /// What the amount typed comes to for this person, as they type.
  String? get _converted {
    final minor = parseAmount(_amount.text, _typedIn);
    if (minor == null || minor <= 0 || _typedIn == widget.viewerCurrency) {
      return null;
    }
    try {
      final shown = widget.rates?.convert(
        Money(minor, _typedIn),
        widget.viewerCurrency,
      );
      return shown == null ? null : _money(shown.minor, shown.currency);
    } on MissingRateException {
      return null;
    }
  }

  void _chooseCurrency(String currency) => setState(() {
    _typedIn = currency;
    _error = null;
    // Start again from the full amount, in the new currency.
    _amount.text = switch (_maxHere) {
      final max? => amountText(max, currency),
      null => '',
    };
  });

  void _save() {
    final max = _maxHere;
    final minor = parseAmount(_amount.text, _typedIn);
    final inTrip = _inTrip;
    setState(
      () => _error = max == null
          ? 'Can’t convert $_typedIn yet: no exchange rates.'
          : minor == null || minor <= 0 || inTrip == null || inTrip <= 0
          ? 'Enter an amount above zero.'
          : inTrip > widget.suggestedMinor
          ? 'Up to ${_money(max, _typedIn)}.'
          : null,
    );
    if (_error == null) Navigator.pop(context, inTrip);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final max = _maxHere;
    final converted = _converted;
    final inTrip = _inTrip;
    final showTrip =
        _typedIn != widget.currency &&
        widget.currency != widget.viewerCurrency &&
        inTrip != null &&
        inTrip > 0 &&
        inTrip <= widget.suggestedMinor;
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SingleChildScrollView(
        // Clear of the phone's navigation buttons, which the keyboard covers.
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + (keyboard > 0 ? 0 : media.viewPadding.bottom),
        ),
        child: ConstrainedBox(
          // Tall enough to bring the amount up to about the middle of the
          // screen; with the keyboard open, as short as it can be.
          constraints: BoxConstraints(
            minHeight: keyboard > 0 ? 0 : media.size.height * _tallShare,
          ),
          child: IntrinsicHeight(
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                          LengthLimitingTextInputFormatter(16),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Amount paid',
                          errorText: _error,
                          errorMaxLines: 2,
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _save(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _typedIn,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                        ),
                        items: [
                          for (final c in {
                            widget.currency,
                            widget.viewerCurrency,
                            ...widget.currencies,
                          })
                            DropdownMenuItem(value: c, child: Text(c)),
                        ],
                        onChanged: (c) {
                          if (c != null) _chooseCurrency(c);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  max == null
                      ? 'Can’t convert $_typedIn yet: no exchange rates.'
                      : 'Up to ${_money(max, _typedIn)}. '
                            'Lower it for a part payment.',
                  style: text.bodySmall?.copyWith(color: RoamioColors.slate),
                ),
                if (converted != null) ...[
                  const SizedBox(height: 4),
                  Text('≈ $converted in your currency', style: text.bodyMedium),
                ],
                if (showTrip) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Recorded as ${_money(inTrip, widget.currency)}, '
                    'the trip’s currency.',
                    style: text.bodySmall?.copyWith(color: RoamioColors.slate),
                  ),
                ],
                const SizedBox(height: 16),
                const Spacer(),
                PrimaryButton(label: 'Mark as settled', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
