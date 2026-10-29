import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/age.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/split_engine.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';

/// What stops a tab being saved (spec UC-21).
enum TabProblem {
  noAmount,
  tooBig,
  futureDate,
  noCategory,
  nobodySharing,
  closed,

  /// Split payment is on and the payers don't add up to the amount.
  paymentsDontAddUp,

  /// Custom % is on and the percentages don't make exactly 100.00%.
  percentagesDontAddUp,
}

final _percentText = RegExp(r'^\d{1,3}(\.\d{1,2})?$');

/// Reads "33.33" as 3333 basis points; null unless 0 to 100 with at most
/// two decimals (spec §6: percentages are basis points, never floats).
int? parsePercent(String text) {
  final t = text.trim();
  if (!_percentText.hasMatch(t)) return null;
  final parts = t.split('.');
  final bp =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return bp <= fullBasisPoints ? bp : null;
}

/// 3333 → "33.33%", 5050 → "50.5%", 10000 → "100%".
String formatBasisPoints(int bp) {
  final whole = bp ~/ 100;
  final cents = bp % 100;
  if (cents == 0) return '$whole%';
  final fraction = cents
      .toString()
      .padLeft(2, '0')
      .replaceFirst(RegExp(r'0$'), '');
  return '$whole.$fraction%';
}

/// 100% shared equally, the spare basis points going to the first people.
Map<String, int> equalPercents(List<String> ids) {
  final parts = allocate(fullBasisPoints, [for (final _ in ids) 1]);
  return {for (final (i, id) in ids.indexed) id: parts[i]};
}

/// The people who paid something, from the amounts typed per member.
List<Payment> payersFrom(Map<String, String> texts, String currency) => [
  for (final MapEntry(:key, :value) in texts.entries)
    if (parseAmount(value, currency) case final minor? when minor > 0)
      Payment(key, minor),
];

/// Basis points per participant from what was typed; null if any is unreadable.
Map<String, int>? percentsFrom(Map<String, String> texts) {
  final out = <String, int>{};
  for (final MapEntry(:key, :value) in texts.entries) {
    final bp = parsePercent(value);
    if (bp == null) return null;
    out[key] = bp;
  }
  return out;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Checks the Add Tab form. [amountText] is what was typed, in [currency].
Set<TabProblem> tabProblems({
  required Adventure adventure,
  required String amountText,
  required String currency,
  required DateTime date,
  required DateTime today,
  required String? category,
  required List<String> participants,

  /// Amount typed per member when the payment is split; null when you paid
  /// it all.
  Map<String, String>? payerTexts,

  /// Percentage typed per participant in Custom % mode; null for Equal.
  Map<String, String>? percentTexts,
}) {
  final minor = parseAmount(amountText, currency);
  final payers = payerTexts == null ? null : payersFrom(payerTexts, currency);
  final paid = payers?.fold(0, (sum, p) => sum + p.amountMinor);
  final percents = percentTexts == null ? null : percentsFrom(percentTexts);
  return {
    if (minor == null || minor <= 0)
      TabProblem.noAmount
    else if (minor > maxTabMinor(currency))
      TabProblem.tooBig,
    if (_day(date).isAfter(_day(today))) TabProblem.futureDate,
    if (category == null) TabProblem.noCategory,
    if (participants.isEmpty) TabProblem.nobodySharing,
    if (!adventure.tabsOpenOn(today)) TabProblem.closed,
    if (payerTexts != null &&
        (payerTexts.values.any(
              (t) => t.trim().isNotEmpty && parseAmount(t, currency) == null,
            ) ||
            paid == 0 ||
            paid != minor))
      TabProblem.paymentsDontAddUp,
    if (percentTexts != null &&
        (percents == null ||
            percents.length != participants.length ||
            !participants.every(percents.containsKey) ||
            percents.values.any((bp) => bp <= 0) ||
            percents.values.fold(0, (a, b) => a + b) != fullBasisPoints))
      TabProblem.percentagesDontAddUp,
  };
}

/// A tab ready to save: who paid what, and how it's shared (equal unless
/// [percentBp] is set).
class NewTab {
  const new({
    required this.description,
    required this.category,
    required this.amountMinor,
    required this.currency,
    required this.date,
    required this.payers,
    required this.participants,
    this.percentBp,
    this.location,
  });

  final String description;
  final String category;
  final int amountMinor;
  final String currency;
  final DateTime date;
  final List<Payment> payers;
  final List<String> participants;

  /// Each participant's share in basis points; null for an equal split.
  final Map<String, int>? percentBp;

  /// Where it happened, if an adult chose to add it (spec UC-21, §7.2).
  final MapPoint? location;

  /// Rates from the tab's own day convert it, so totals never shift (§9.1).
  String get fxDate => isoDate(date);

  TabSplit get split => TabSplit(
    amount: Money(amountMinor, currency),
    payers: payers,
    participants: participants,
    percentBp: percentBp,
    fxDate: fxDate,
  );

  /// What [id] owes for this tab, in its currency minor units.
  int shareOf(String id) => sharesFor(split)[id] ?? 0;
}
