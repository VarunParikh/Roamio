import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/tabs/domain/payment_method.dart';

/// A member's uid or a pal's id. Pals have their own balance (spec §5.5).
typedef ParticipantId = String;

/// 100% in basis points (spec §6).
const fullBasisPoints = 10000;

/// One payer's part of a tab, in the tab's currency minor units.
class Payment {
  const new(this.payer, this.amountMinor, {this.method = PaymentMethod.other});

  final ParticipantId payer;
  final int amountMinor;

  /// How they paid (spec UC-21). No part of the split maths.
  final PaymentMethod method;
}

/// The money facts of one tab: who paid, who shares, and how.
///
/// [percentBp] is null for an equal split; otherwise it maps every
/// participant to their share in basis points.
class TabSplit {
  const new({
    required this.amount,
    required this.payers,
    required this.participants,
    required this.fxDate,
    this.percentBp,
  });

  final Money amount;
  final List<Payment> payers;

  /// Order matters: the spare minor unit of a split goes to the first ones.
  final List<ParticipantId> participants;
  final Map<ParticipantId, int>? percentBp;

  /// The day whose exchange rates convert this tab (spec §9.1).
  final String fxDate;
}

/// A recorded "Mark as settled" payment outside the app (UC-26a),
/// in the adventure's base currency.
class Settlement {
  const new({required this.from, required this.to, required this.amount});

  final ParticipantId from;
  final ParticipantId to;
  final Money amount;
}

/// Why a tab can't be split; the Add Tab screen maps each to a message.
enum SplitProblem {
  nonPositiveAmount('the amount must be more than zero'),
  noParticipants('nobody is sharing the tab'),
  duplicateParticipant('someone is listed twice'),
  noPayers('nobody paid'),
  duplicatePayer('a payer is listed twice'),
  nonPositivePayment('each payer must pay more than zero'),
  paymentsDontAddUp('the payments must add up to the amount'),
  percentagesDontMatchParticipants('every participant needs a percentage'),
  nonPositivePercentage('each percentage must be more than zero'),
  percentagesDontAddUp('the percentages must add up to 100%');

  new(this.description);

  final String description;
}

class InvalidTabException implements Exception {
  new(this.problems);

  final List<SplitProblem> problems;

  @override
  String toString() =>
      'InvalidTabException: ${problems.map((p) => p.description).join('; ')}';
}
