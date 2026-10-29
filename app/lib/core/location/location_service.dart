import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// One point on the map; all a tab stores about where it happened.
class MapPoint {
  const new(this.lat, this.lng);

  final double lat;
  final double lng;
}

/// What asking for the current location gave.
sealed class LocationResult {
  const new();
}

class Located extends LocationResult {
  const new(this.point);

  final MapPoint point;
}

/// The phone's location services are switched off.
class LocationServicesOff extends LocationResult {
  const new();
}

/// The person said no; [forever] means Android won't ask again, so only
/// the app's settings page can change it.
class LocationDenied extends LocationResult {
  const new({required this.forever});

  final bool forever;
}

class LocationFailed extends LocationResult {
  const new();
}

/// Reads the current location once, when the person asks (spec UC-21).
/// Callers must check `privacyPolicyProvider.allowsLocation` first.
abstract interface class LocationService {
  Future<LocationResult> current();

  /// Where the phone is, only if location is already allowed and on; never
  /// asks. Null otherwise. For background uses such as the weather (UC-7).
  Future<MapPoint?> currentIfAllowed();

  /// Opens the phone's location settings to switch services on.
  Future<void> openLocationSettings();

  /// Opens this app's settings page to allow location.
  Future<void> openAppSettings();
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => DeviceLocationService(),
);

class DeviceLocationService implements LocationService {
  @override
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationServicesOff();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationDenied(forever: false);
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationDenied(forever: true);
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 15),
        ),
      );
      return Located(MapPoint(p.latitude, p.longitude));
    } on Exception {
      return const LocationFailed();
    }
  }

  @override
  Future<MapPoint?> currentIfAllowed() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final p =
          await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 10),
            ),
          );
      return MapPoint(p.latitude, p.longitude);
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}
