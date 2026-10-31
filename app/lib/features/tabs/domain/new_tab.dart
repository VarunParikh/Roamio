import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/age.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/split_engine.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/domain/payment_method.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

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

  /// Someone who paid has no Paid with yet.
  noPaymentMethod,
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

/// The people who paid something, from the amounts typed per member, each
/// with how they paid ([methodOf]).
List<Payment> payersFrom(
  Map<String, String> texts,
  String currency, {
  PaymentMethod? Function(String id)? methodOf,
}) => [
  for (final MapEntry(:key, :value) in texts.entries)
    if (parseAmount(value, currency) case final minor? when minor > 0)
      Payment(key, minor, method: methodOf?.call(key) ?? PaymentMethod.other),
];

/// The amounts typed for the people still on the squad. Someone removed
/// while the form was open is dropped rather than saved as a payer, which
/// the server would refuse (spec UC-16).
Map<String, String> payerTextsOf(
  Map<String, String> texts,
  Iterable<String> people,
) {
  final on = people.toSet();
  return {
    for (final MapEntry(:key, :value) in texts.entries)
      if (on.contains(key)) key: value,
  };
}

/// What the phone remembers from a new tab: your own method, or the first
/// payer's if you didn't pay.
PaymentMethod rememberedMethod(List<Payment> payers, String myUid) =>
    payers.where((p) => p.payer == myUid).firstOrNull?.method ??
    payers.first.method;

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

  /// Who is adding it: leads have a week longer than members (UC-11).
  required String myUid,
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

  /// Paid with for each person who paid; null for one with none chosen.
  List<PaymentMethod?>? paymentMethods,
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
    if (!adventure.tabsOpenFor(myUid, today)) TabProblem.closed,
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
    if (paymentMethods?.contains(null) ?? false) TabProblem.noPaymentMethod,
  };
}

/// The day whose exchange rates convert a tab, saved with it so its total
/// never shifts (spec §9.1, follow-up C4): the day of the latest rates
/// known when it's saved ([ratesDay]), never after the tab's [date]; the
/// tab's own day if none are known yet. An edit keeps its [previous] rate
/// day unless the date changes.
String fxDateFor({
  required DateTime date,
  String? ratesDay,
  ({DateTime date, String fxDate})? previous,
}) {
  final day = isoDate(date);
  if (previous != null && isoDate(previous.date) == day) return previous.fxDate;
  return ratesDay != null && ratesDay.compareTo(day) <= 0 ? ratesDay : day;
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
    this.basedOn,
    this._fxDate,
    this.status = TabStatus.waiting,
  });

  /// How a new tab starts (spec UC-21a); an edit keeps the tab's status.
  final TabStatus status;

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

  /// On an edit: the saved version being edited, so the server can tell if
  /// this edit replaced a newer one (spec UC-32).
  final DateTime? basedOn;

  final String? _fxDate;

  /// The day whose rates convert it (see [fxDateFor]); the tab's own day
  /// if none was given.
  String get fxDate => _fxDate ?? isoDate(date);

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
