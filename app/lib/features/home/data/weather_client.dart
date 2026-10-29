import 'dart:convert';
import 'dart:io';

import 'package:roamio/core/location/location_service.dart';

/// Current weather for the Hero card (spec UC-7).
class Weather {
  const new({required this.temperatureC, required this.code});

  final int temperatureC;

  /// WMO weather code, as Open-Meteo reports it.
  final int code;

  String get label => switch (code) {
    0 => 'Clear',
    1 => 'Mainly clear',
    2 => 'Partly cloudy',
    3 => 'Cloudy',
    45 || 48 => 'Fog',
    >= 51 && <= 57 => 'Drizzle',
    >= 61 && <= 67 || >= 80 && <= 82 => 'Rain',
    >= 71 && <= 77 || 85 || 86 => 'Snow',
    >= 95 => 'Thunderstorm',
    _ => 'Weather',
  };

  String get emoji => switch (code) {
    0 || 1 => '☀️',
    2 => '⛅',
    3 || 45 || 48 => '☁️',
    >= 71 && <= 77 || 85 || 86 => '❄️',
    >= 95 => '⛈️',
    _ => '🌧️',
  };
}

/// Fetches and decodes JSON from [uri]; throws on any failure.
typedef FetchJson = Future<Object?> Function(Uri uri);

/// Open-Meteo (free, no key), cached 30 minutes; any failure gives null
/// so the card simply hides the weather (spec §9.3).
class WeatherClient {
  new(this._fetch, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final FetchJson _fetch;
  final DateTime Function() _now;
  final _cache = <String, (DateTime, Weather)>{};
  final _places = <String, MapPoint>{};

  static const _keep = Duration(minutes: 30);

  /// About 1 km: all the precision weather needs, and all that leaves
  /// the phone.
  static double _round(double v) => (v * 100).round() / 100;

  Future<Weather?> forPoint(MapPoint point) async {
    final lat = _round(point.lat);
    final lng = _round(point.lng);
    final key = '$lat,$lng';
    final cached = _cache[key];
    if (cached != null && _now().difference(cached.$1) < _keep) {
      return cached.$2;
    }
    try {
      final json = await _fetch(
        Uri.https('api.open-meteo.com', '/v1/forecast', {
          'latitude': '$lat',
          'longitude': '$lng',
          'current': 'temperature_2m,weather_code',
        }),
      );
      final current = (json! as Map)['current'] as Map;
      final weather = Weather(
        temperatureC: (current['temperature_2m'] as num).round(),
        code: (current['weather_code'] as num).toInt(),
      );
      _cache[key] = (_now(), weather);
      return weather;
    } on Object {
      return null;
    }
  }

  /// The weather in [city] (or the country itself when there's no city).
  Future<Weather?> forCity(String city, String countryCode) async {
    final key = '$city|$countryCode';
    var point = _places[key];
    if (point == null) {
      try {
        final json = await _fetch(
          Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
            'name': city,
            'count': '1',
            'countryCode': countryCode,
          }),
        );
        final first = ((json! as Map)['results'] as List).first as Map;
        point = MapPoint(
          (first['latitude'] as num).toDouble(),
          (first['longitude'] as num).toDouble(),
        );
        _places[key] = point;
      } on Object {
        return null;
      }
    }
    return await forPoint(point);
  }
}

/// The real [FetchJson]: a plain HTTPS GET with a short timeout.
Future<Object?> fetchJsonOverHttp(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final request = await client.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    return jsonDecode(await response.transform(utf8.decoder).join());
  } finally {
    client.close();
  }
}
