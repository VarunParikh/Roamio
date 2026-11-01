import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:geocoding/geocoding.dart' show Geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:roamio/core/privacy/privacy_policy.dart';

/// One point on the map; all a tab stores about where it happened.
class MapPoint {
  const new(this.lat, this.lng);

  final double lat;
  final double lng;

  /// As text, to about 10 metres: "13.7563, 100.5018".
  String get label => '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
}

/// A place's short name from what a lookup gave: "Bangkok, Thailand". The town
/// if there is one, otherwise the wider area. Null if there's nothing to show.
String? placeName({String? locality, String? area, String? country}) {
  String? clean(String? text) {
    final t = text?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  final parts = [clean(locality) ?? clean(area), clean(country)].nonNulls;
  return parts.isEmpty ? null : parts.join(', ');
}

/// Names for points on the map (spec UC-21). Null when there's no name, such
/// as offline: callers show the coordinates instead.
abstract interface class PlaceNames {
  Future<String?> nameOf(MapPoint point);
}

/// No names, for tests and anywhere the phone's service isn't wired in.
class NoPlaceNames implements PlaceNames {
  const new();

  @override
  Future<String?> nameOf(MapPoint point) async => null;
}

/// The phone's own service (Android's Geocoder: free, no key). It can fail or
/// have no answer, especially offline, and that just means no name.
class DevicePlaceNames implements PlaceNames {
  const new();

  @override
  Future<String?> nameOf(MapPoint point) async {
    try {
      final found = await Geocoding().placemarkFromCoordinates(
        point.lat,
        point.lng,
      );
      if (found.isEmpty) return null;
      return placeName(
        locality: found.first.locality,
        area: found.first.administrativeArea,
        country: found.first.country,
      );
    } on Object {
      return null;
    }
  }
}

/// Overridden in `main.dart` with the phone's own service.
final placeNamesProvider = Provider<PlaceNames>((ref) => const NoPlaceNames());

/// A point's name, looked up once per session, since the phone's service limits
/// how often it can be asked. Nothing is sent for anyone not confirmed as an
/// adult: looking a place up can send it off the phone (CLAUDE.md, §7.2).
final FutureProviderFamily<String?, (double, double)> placeNameProvider =
    FutureProvider.family<String?, (double, double)>((ref, point) async {
      if (!ref.watch(privacyPolicyProvider).allowsLocation) return null;
      return await ref
          .watch(placeNamesProvider)
          .nameOf(MapPoint(point.$1, point.$2));
    });

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
