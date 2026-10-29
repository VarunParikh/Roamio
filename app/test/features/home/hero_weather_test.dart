import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_location_service.dart';
import '../../support/fake_profile_service.dart';

final _chiangMai = Adventure(
  id: 'cnx',
  name: 'Chiang Mai trip',
  countryCode: 'TH',
  city: 'Chiang Mai',
  startDate: DateTime(2026, 10, 27),
  endDate: DateTime(2026, 11, 2),
  baseCurrency: 'THB',
  leaderUid: 'ari',
  memberUids: const ['ari'],
);

/// Open-Meteo stand-in: a city search and a forecast; records each host.
class _OpenMeteo {
  final List<String> hosts = [];
  bool down = false;

  Future<Object?> call(Uri uri) async {
    hosts.add(uri.host);
    if (down) throw Exception('offline');
    return uri.host.startsWith('geocoding')
        ? {
            'results': [
              {'latitude': 18.79, 'longitude': 98.98},
            ],
          }
        : {
            'current': {'temperature_2m': 29.6, 'weather_code': 0},
          };
  }
}

Future<void> _home(
  WidgetTester tester, {
  required _OpenMeteo web,
  SessionFacts facts = readyFacts,
  FakeLocationService? location,
  FakeProfileService? profile,
  bool weatherEnabled = true,
}) => pumpRoamio(
  tester,
  FakeAuthService(initial: facts),
  adventures: FakeAdventureService([_chiangMai]),
  weatherFetch: web.call,
  weatherEnabled: weatherEnabled,
  location: location,
  profile: profile,
);

void main() {
  group('Weather on the Hero card (UC-7)', () {
    testWidgets('uses where you are when you allow location', (tester) async {
      final web = _OpenMeteo();
      final location = FakeLocationService()
        ..allowed = const MapPoint(13.75, 100.5);
      await _home(
        tester,
        web: web,
        location: location,
        profile: FakeProfileService(location: true),
      );

      expect(find.text('☀️ 30°C'), findsOneWidget);
      expect(web.hosts, ['api.open-meteo.com']);
      expect(location.backgroundReads, 1);
      expect(location.calls, isEmpty);
    });

    testWidgets('otherwise the adventure’s city, without asking for '
        'location', (tester) async {
      final web = _OpenMeteo();
      final location = FakeLocationService()
        ..allowed = const MapPoint(13.75, 100.5);
      // The Location switch is off.
      await _home(tester, web: web, location: location);

      expect(find.text('☀️ 30°C'), findsOneWidget);
      expect(web.hosts, ['geocoding-api.open-meteo.com', 'api.open-meteo.com']);
      expect(location.backgroundReads, 0);
    });

    testWidgets('under-18s always get the city (§7.2)', (tester) async {
      final web = _OpenMeteo();
      final location = FakeLocationService()
        ..allowed = const MapPoint(13.75, 100.5);
      await _home(
        tester,
        web: web,
        location: location,
        profile: FakeProfileService(location: true),
        facts: const SessionFacts(
          uid: 'ari',
          hasAccount: true,
          ageStatus: 'minor_active',
        ),
      );

      expect(find.text('☀️ 30°C'), findsOneWidget);
      expect(location.backgroundReads, 0);
    });

    testWidgets('hidden, never an error, when the weather is unavailable', (
      tester,
    ) async {
      final web = _OpenMeteo()..down = true;
      await _home(tester, web: web);

      expect(find.text('Chiang Mai trip'), findsOneWidget);
      expect(find.textContaining('°C'), findsNothing);
    });

    testWidgets('switched off by the weather_enabled flag (§11)', (
      tester,
    ) async {
      final web = _OpenMeteo();
      await _home(tester, web: web, weatherEnabled: false);

      expect(find.textContaining('°C'), findsNothing);
      expect(web.hosts, isEmpty);
    });
  });
}
