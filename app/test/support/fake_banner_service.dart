import 'package:roamio/features/banners/data/banner_service.dart';

/// Returns [banners] by country code; anything else has no banner.
class FakeBannerService implements BannerService {
  new([this.banners = const {}]);

  final Map<String, BannerPhoto> banners;

  @override
  Future<BannerPhoto?> bannerFor(String countryCode) async =>
      banners[countryCode];
}
