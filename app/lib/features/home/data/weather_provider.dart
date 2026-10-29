import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:roamio/core/config/remote_config.dart';
import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/core/privacy/privacy_policy.dart';
import 'package:roamio/features/home/data/weather_client.dart';
import 'package:roamio/features/profile/data/profile_service.dart';

/// Remote Config `weather_enabled` (spec §11), on unless switched off there.
final weatherEnabledProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).weatherEnabled,
);

/// One client for the app, so its 30-minute cache is shared.
final weatherClientProvider = Provider<WeatherClient>(
  (ref) => WeatherClient(fetchJsonOverHttp),
);

/// The Hero card's weather for an adventure in (city, country code): where
/// the person is when they allow location (adults only, §7.2), otherwise
/// the adventure's city. Null hides it (UC-7).
final FutureProviderFamily<Weather?, (String, String)> heroWeatherProvider =
    FutureProvider.family<Weather?, (String, String)>((ref, place) async {
      if (!ref.watch(weatherEnabledProvider)) return null;
      final client = ref.watch(weatherClientProvider);
      if (ref.watch(privacyPolicyProvider).allowsLocation &&
          await ref.watch(locationAllowedProvider.future)) {
        final here = await ref.read(locationServiceProvider).currentIfAllowed();
        if (here != null) return await client.forPoint(here);
      }
      final (city, countryCode) = place;
      return await client.forCity(city, countryCode);
    });
