import 'package:meta/meta.dart';

/// A trip (spec glossary). Dates are whole days in the traveller's calendar.
@immutable
class Adventure {
  const new({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.startDate,
    required this.endDate,
    required this.baseCurrency,
    required this.leaderUid,
    required this.memberUids,
    this.description = '',
    this.city = '',
    this.bannerUrl,
    this.coLeadUids = const [],
    this.activeInviteCode,
    this.hasTabs = false,
  });

  final String id;
  final String name;
  final String description;
  final String countryCode;
  final String city;
  final DateTime startDate;
  final DateTime endDate;
  final String baseCurrency;
  final String? bannerUrl;
  final String leaderUid;
  final List<String> coLeadUids;
  final List<String> memberUids;

  /// The current invite code, if a lead has shared one (server-set).
  final String? activeInviteCode;

  /// Whether any tab exists yet (server-set).
  final bool hasTabs;

  /// The trip currency can't change once a tab exists (UC-10).
  bool get currencyLocked => hasTabs;

  /// How long after the end date tabs can still be added (UC-11).
  static const tabGraceDays = 7;

  /// Tabs can be added until [tabGraceDays] after the last day (UC-11).
  bool tabsOpenOn(DateTime today) {
    final e = _day(endDate);
    final lastDay = DateTime(e.year, e.month, e.day + tabGraceDays);
    return !_day(today).isAfter(lastDay);
  }

  bool isLead(String uid) => uid == leaderUid || coLeadUids.contains(uid);

  /// The leader, with no co-lead to share decisions with.
  bool isOnlyAdmin(String uid) => uid == leaderUid && coLeadUids.isEmpty;

  /// Active from the first to the last day; past from the day after (UC-11).
  AdventureStatus statusOn(DateTime today) {
    final day = _day(today);
    if (day.isBefore(_day(startDate))) return AdventureStatus.upcoming;
    if (day.isAfter(_day(endDate))) return AdventureStatus.past;
    return AdventureStatus.active;
  }
}

enum AdventureStatus { upcoming, active, past }

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// How Home lays out someone's adventures (UC-5).
class HomeSections {
  const new({required this.hero, required this.upcoming, required this.past});

  /// The adventure happening now, or else the next one.
  final Adventure? hero;

  /// Other current and future adventures, soonest relevant first.
  final List<Adventure> upcoming;

  /// Finished adventures, newest first.
  final List<Adventure> past;

  bool get isEmpty => hero == null && past.isEmpty;
}

HomeSections homeSectionsFor(List<Adventure> all, DateTime today) {
  List<Adventure> where(AdventureStatus s) =>
      all.where((a) => a.statusOn(today) == s).toList();

  final active = where(AdventureStatus.active)
    ..sort((a, b) => b.startDate.compareTo(a.startDate));
  final upcoming = where(AdventureStatus.upcoming)
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
  final past = where(AdventureStatus.past)
    ..sort((a, b) => b.endDate.compareTo(a.endDate));

  final ahead = [...active, ...upcoming];
  return HomeSections(
    hero: ahead.isEmpty ? null : ahead.first,
    upcoming: ahead.skip(1).toList(),
    past: past,
  );
}

enum DraftProblem { noCountry, noName, nameTooLong, noDates, endBeforeStart }

const maxAdventureName = 80;

/// What stops a new adventure being created (UC-8, rules in DATA_MODEL.md).
Set<DraftProblem> draftProblems({
  required String? countryCode,
  required String name,
  required DateTime? start,
  required DateTime? end,
}) => {
  if (countryCode == null) DraftProblem.noCountry,
  if (name.trim().isEmpty) DraftProblem.noName,
  if (name.trim().length > maxAdventureName) DraftProblem.nameTooLong,
  if (start == null || end == null)
    DraftProblem.noDates
  else if (_day(end).isBefore(_day(start)))
    DraftProblem.endBeforeStart,
};
