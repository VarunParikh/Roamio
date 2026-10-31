import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/banners/data/banner_service.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_banner_service.dart';
import '../../support/fake_sync.dart';

/// "Today" is 29 Oct 2026 in pumpRoamio.
Adventure _trip(
  String id,
  String country,
  DateTime start,
  DateTime end, {
  String? bannerUrl,
}) => Adventure(
  id: id,
  name: 'Trip $id',
  countryCode: country,
  startDate: start,
  endDate: end,
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari'],
  bannerUrl: bannerUrl,
);

BannerPhoto _photo(String name) => BannerPhoto(
  url: 'https://images.example.com/$name.webp',
  photographer: 'Asha',
  photographerUrl: 'https://example.com/asha',
);

final Adventure _now = _trip(
  'now',
  'IN',
  DateTime(2026, 10, 20),
  DateTime(2026, 11, 3),
);
final Adventure _next = _trip(
  'next',
  'JP',
  DateTime(2026, 12),
  DateTime(2026, 12, 9),
);
final Adventure _later = _trip(
  'later',
  'FR',
  DateTime(2027),
  DateTime(2027, 1, 9),
);
final Adventure _old = _trip(
  'old',
  'TH',
  DateTime(2026, 6),
  DateTime(2026, 6, 5),
);

Future<List<String>> _home(
  WidgetTester tester, {
  required List<Adventure> adventures,
  FakeConnectivity? connectivity,
}) async {
  final saved = <String>[];
  await pumpRoamio(
    tester,
    FakeAuthService(initial: readyFacts),
    adventures: FakeAdventureService(adventures),
    banners: FakeBannerService({
      'IN': _photo('india'),
      'JP': _photo('japan'),
      'FR': _photo('france'),
      'TH': _photo('thailand'),
    }),
    connectivity: connectivity,
    savedBanners: saved,
  );
  return saved;
}

void main() {
  group('saving banners for travel (spec §9.2)', () {
    testWidgets('every current and upcoming trip, even off screen', (
      tester,
    ) async {
      final saved = await _home(tester, adventures: [_now, _next, _later]);
      expect(
        saved,
        unorderedEquals([
          _photo('india').url,
          _photo('japan').url,
          _photo('france').url,
        ]),
      );
    });

    testWidgets('not past trips', (tester) async {
      final saved = await _home(tester, adventures: [_now, _old]);
      expect(saved, [_photo('india').url]);
    });

    testWidgets('a trip with its own photo saves that one', (tester) async {
      final saved = await _home(
        tester,
        adventures: [
          _trip(
            'own',
            'IN',
            DateTime(2026, 10, 20),
            DateTime(2026, 11, 3),
            bannerUrl: 'https://images.example.com/own.webp',
          ),
        ],
      );
      expect(saved, ['https://images.example.com/own.webp']);
    });

    testWidgets('two trips in one country save it once', (tester) async {
      final saved = await _home(
        tester,
        adventures: [
          _now,
          _trip('again', 'IN', DateTime(2026, 12), DateTime(2026, 12, 9)),
        ],
      );
      expect(saved, [_photo('india').url]);
    });

    testWidgets('a trip that joins later is saved too', (tester) async {
      final adventures = FakeAdventureService([_now]);
      final saved = <String>[];
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: adventures,
        banners: FakeBannerService({
          'IN': _photo('india'),
          'JP': _photo('japan'),
        }),
        savedBanners: saved,
      );
      adventures.arrive(_next);
      await tester.pumpAndSettle();
      expect(saved, containsAll([_photo('japan').url]));
    });

    testWidgets('offline waits, then saves when the connection is back', (
      tester,
    ) async {
      final connectivity = FakeConnectivity(online: false);
      final saved = await _home(
        tester,
        adventures: [_now],
        connectivity: connectivity,
      );
      expect(saved, isEmpty);

      connectivity.set(online: true);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(saved, [_photo('india').url]);
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
