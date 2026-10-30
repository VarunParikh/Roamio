/// How someone paid their part of a tab (spec UC-21). It only records this;
/// Roamio moves no money.
enum PaymentMethod {
  cash('cash', '💵', 'Cash'),
  card('card', '💳', 'Card'),
  upi('upi', '📱', 'UPI'),
  cheque('cheque', '📝', 'Cheque'),
  bankTransfer('bank_transfer', '🏦', 'Bank transfer'),
  other('other', '🔖', 'Other');

  new(this.id, this.emoji, this.label);

  /// What's stored in `payers[].method`.
  final String id;
  final String emoji;
  final String label;

  /// The method with this stored id; null if there's none.
  static PaymentMethod? byId(Object? id) {
    for (final m in values) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// From a saved tab. Older tabs have none and newer apps may add more, so
  /// anything unknown shows as Other and never makes a tab invalid.
  static PaymentMethod fromStored(Object? stored) => byId(stored) ?? other;
}

/// "Paid with Cash, Card and UPI", each once; what TalkBack reads instead of
/// the emoji.
String paidWithLabel(Iterable<PaymentMethod> methods) {
  final names = [for (final m in methods.toSet()) m.label];
  final last = names.removeLast();
  return names.isEmpty
      ? 'Paid with $last'
      : 'Paid with ${names.join(', ')} and $last';
}
