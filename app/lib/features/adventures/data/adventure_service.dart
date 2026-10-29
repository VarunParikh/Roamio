import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';

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

/// What a lead can change about an adventure (UC-10).
class AdventureEdit {
  const new({
    required this.name,
    required this.description,
    required this.city,
    required this.startDate,
    required this.endDate,
    this.baseCurrency,
  });

  final String name;
  final String description;
  final String city;
  final DateTime startDate;
  final DateTime endDate;

  /// Null leaves it unchanged, as it must once the adventure has tabs.
  final String? baseCurrency;
}

/// Overridden in `main.dart` with the Firebase implementation.
final adventureServiceProvider = Provider<AdventureService>(
  (ref) =>
      throw UnimplementedError('adventureServiceProvider must be overridden'),
);

final myAdventuresProvider = StreamProvider<List<Adventure>>(
  (ref) => ref.watch(adventureServiceProvider).myAdventures(),
);
