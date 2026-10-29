import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/features/home/data/weather_client.dart';

const Map<String, Object?> _bangkokNow = {
  'current': {'temperature_2m': 31.4, 'weather_code': 2},
};

/// Answers Open-Meteo requests from [answers] by host, recording each URL.
class _Web {
  new(this.answers);

  final Map<String, Object? Function(Uri)> answers;
  final List<Uri> asked = [];

  Future<Object?> call(Uri uri) async {
    asked.add(uri);
    return answers[uri.host]!(uri);
  }
}

void main() {
  group('WeatherClient (spec UC-7, §9.3)', () {
    test('reads the current temperature and sky for a point', () async {
      final web = _Web({'api.open-meteo.com': (_) => _bangkokNow});
      final client = WeatherClient(web.call, now: () => DateTime(2026, 10, 29));

      final w = await client.forPoint(const MapPoint(13.756331, 100.501765));

      expect(w?.temperatureC, 31);
      expect(w?.label, 'Partly cloudy');
      // Only about 1 km of precision leaves the phone.
      expect(web.asked.single.queryParameters['latitude'], '13.76');
      expect(web.asked.single.queryParameters['longitude'], '100.5');
    });

    test('keeps an answer for 30 minutes, then asks again', () async {
      var now = DateTime(2026, 10, 29, 9);
      final web = _Web({'api.open-meteo.com': (_) => _bangkokNow});
      final client = WeatherClient(web.call, now: () => now);
      const point = MapPoint(13.75, 100.5);

      await client.forPoint(point);
      now = now.add(const Duration(minutes: 29));
      await client.forPoint(point);
      expect(web.asked, hasLength(1));

      now = now.add(const Duration(minutes: 2));
      await client.forPoint(point);
      expect(web.asked, hasLength(2));
    });

    test('finds a city first, then its weather', () async {
      final web = _Web({
        'geocoding-api.open-meteo.com': (_) => {
          'results': [
            {'latitude': 18.79, 'longitude': 98.98},
          ],
        },
        'api.open-meteo.com': (_) => _bangkokNow,
      });
      final client = WeatherClient(web.call, now: () => DateTime(2026, 10, 29));

      final w = await client.forCity('Chiang Mai', 'TH');

      expect(w?.temperatureC, 31);
      expect(
        web.asked.first.queryParameters,
        containsPair('name', 'Chiang Mai'),
      );
      expect(
        web.asked.first.queryParameters,
        containsPair('countryCode', 'TH'),
      );
      expect(web.asked.last.queryParameters['latitude'], '18.79');
    });

    test('gives nothing, never an error, when anything goes wrong', () async {
      final now = DateTime(2026, 10, 29);
      Future<Object?> fails(Uri _) => throw Exception('offline');
      expect(
        await WeatherClient(
          fails,
          now: () => now,
        ).forPoint(const MapPoint(1, 2)),
        isNull,
      );
      final garbage = _Web({
        'api.open-meteo.com': (_) => {'current': 'x'},
      });
      expect(
        await WeatherClient(
          garbage.call,
          now: () => now,
        ).forPoint(const MapPoint(1, 2)),
        isNull,
      );
      final nowhere = _Web({
        'geocoding-api.open-meteo.com': (_) => <String, Object?>{},
      });
      expect(
        await WeatherClient(
          nowhere.call,
          now: () => now,
        ).forCity('Atlantis', 'GR'),
        isNull,
      );
    });

    test('a failure isn’t cached, so the next look tries again', () async {
      var fail = true;
      final web = _Web({
        'api.open-meteo.com': (_) =>
            fail ? throw Exception('down') : _bangkokNow,
      });
      final client = WeatherClient(web.call, now: () => DateTime(2026, 10, 29));
      const point = MapPoint(13.75, 100.5);

      expect(await client.forPoint(point), isNull);
      fail = false;
      expect((await client.forPoint(point))?.temperatureC, 31);
    });
  });
}
