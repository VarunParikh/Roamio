import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/age.dart';

/// What a person fills in to start an adventure (UC-8).
class AdventureDraft {
  const new({
    required this.name,
    required this.countryCode,
    required this.startDate,
    required this.endDate,
    required this.baseCurrency,
    this.city = '',
    this.description = '',
  });

  final String name;
  final String countryCode;
  final String city;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final String baseCurrency;
}

abstract interface class AdventureService {
  /// Adventures the signed-in person is a member of.
  Stream<List<Adventure>> myAdventures();

  /// Creates the adventure with the creator as Squad Leader; returns its id.
  Future<String> create(AdventureDraft draft);

  /// Leads edit the details (UC-10). The country can't change.
  Future<void> update(String adventureId, AdventureEdit edit);

  /// Drops a lead's own banner photo, so the country photo shows again.
  Future<void> resetBanner(String adventureId);
}

/// What a lead can change about an adventure (UC-10). A null field is left
/// unchanged: a save writes only what the lead changed, so it can't overwrite
/// another lead's change to a field it never touched (item 6).
class AdventureEdit {
  const new({
    this.name,
    this.description,
    this.city,
    this.startDate,
    this.endDate,
    this.baseCurrency,
  });

  final String? name;
  final String? description;
  final String? city;
  final DateTime? startDate;
  final DateTime? endDate;

  /// Null leaves it unchanged, as it must once the adventure has tabs.
  final String? baseCurrency;

  /// Nothing to save.
  bool get isEmpty =>
      name == null &&
      description == null &&
      city == null &&
      startDate == null &&
      endDate == null &&
      baseCurrency == null;
}

/// The edit for what the form now says, against the adventure it opened with:
/// only the fields that differ are set (see [AdventureEdit]).
AdventureEdit editChanges({
  required Adventure opened,
  required String name,
  required String description,
  required String city,
  required DateTime start,
  required DateTime end,
  required String? currency,
}) => AdventureEdit(
  name: name.trim() == opened.name ? null : name,
  description: description.trim() == opened.description ? null : description,
  city: city.trim() == opened.city ? null : city,
  startDate: isoDate(start) == isoDate(opened.startDate) ? null : start,
  endDate: isoDate(end) == isoDate(opened.endDate) ? null : end,
  baseCurrency: currency == null || currency == opened.baseCurrency
      ? null
      : currency,
);

/// Overridden in `main.dart` with the Firebase implementation.
final adventureServiceProvider = Provider<AdventureService>(
  (ref) =>
      throw UnimplementedError('adventureServiceProvider must be overridden'),
);

final myAdventuresProvider = StreamProvider<List<Adventure>>(
  (ref) => ref.watch(adventureServiceProvider).myAdventures(),
);
