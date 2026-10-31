/// Where a tab stands (spec UC-21a). Only approved tabs count for the squad;
/// a personal one counts only for the one person it's visible to.
enum TabStatus {
  waiting,
  approved,
  rejected,
  personal;

  /// From the stored value. Anything unknown waits, so it never counts by
  /// accident.
  static TabStatus fromStored(String? stored) {
    if (stored == null) return approved;
    for (final s in values) {
      if (s.name == stored) return s;
    }
    return waiting;
  }
}
