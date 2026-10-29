import 'package:roamio/core/location/location_service.dart';

/// Answers each request with the next of [results], or Bangkok.
class FakeLocationService implements LocationService {
  new([List<LocationResult>? results]) : results = [...?results];

  final List<LocationResult> results;
  final List<String> calls = [];

  @override
  Future<LocationResult> current() async {
    calls.add('current');
    return results.isEmpty
        ? const Located(MapPoint(13.7563, 100.5018))
        : results.removeAt(0);
  }

  @override
  Future<void> openLocationSettings() async => calls.add('locationSettings');

  @override
  Future<void> openAppSettings() async => calls.add('appSettings');
}
