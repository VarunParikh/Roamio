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
}) {
  final minor = parseAmount(amountText, currency);
  return {
    if (minor == null || minor <= 0)
      TabProblem.noAmount
    else if (minor > maxTabMinor(currency))
      TabProblem.tooBig,
    if (_day(date).isAfter(_day(today))) TabProblem.futureDate,
    if (category == null) TabProblem.noCategory,
    if (participants.isEmpty) TabProblem.nobodySharing,
    if (!adventure.tabsOpenOn(today)) TabProblem.closed,
  };
}

/// A basic tab (Task 23): one payer covers it all, shared equally.
/// Multiple payers and custom percentages arrive in Task 24.
class NewTab {
  const new({
    required this.description,
    required this.category,
    required this.amountMinor,
    required this.currency,
    required this.date,
    required this.payer,
    required this.participants,
    this.location,
  });

  final String description;
  final String category;
  final int amountMinor;
  final String currency;
  final DateTime date;
  final String payer;
  final List<String> participants;

  /// Where it happened, if an adult chose to add it (spec UC-21, §7.2).
  final MapPoint? location;

  /// Rates from the tab's own day convert it, so totals never shift (§9.1).
  String get fxDate => isoDate(date);

  TabSplit get split => TabSplit(
    amount: Money(amountMinor, currency),
    payers: [Payment(payer, amountMinor)],
    participants: participants,
    fxDate: fxDate,
  );

  /// What [id] owes for this tab, in its currency minor units.
  int shareOf(String id) => sharesFor(split)[id] ?? 0;
}
