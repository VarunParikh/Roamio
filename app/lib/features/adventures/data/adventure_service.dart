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
}

/// Overridden in `main.dart` with the Firebase implementation.
final adventureServiceProvider = Provider<AdventureService>(
  (ref) =>
      throw UnimplementedError('adventureServiceProvider must be overridden'),
);

final myAdventuresProvider = StreamProvider<List<Adventure>>(
  (ref) => ref.watch(adventureServiceProvider).myAdventures(),
);
