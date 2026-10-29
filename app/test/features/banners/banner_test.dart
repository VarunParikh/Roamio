import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/banners/data/banner_service.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_banner_service.dart';

void main() {
  final bangkok = Adventure(
    id: 'bkk',
    name: 'Bangkok',
    countryCode: 'TH',
    startDate: DateTime(2026, 10, 27),
    endDate: DateTime(2026, 11, 2),
    baseCurrency: 'THB',
    leaderUid: 'ari',
    memberUids: const ['ari'],
  );
  const photo = BannerPhoto(
    url: 'https://images.unsplash.com/photo-123?w=1600&fm=webp&q=80',
    photographer: 'Jane Doe',
    photographerUrl: 'https://unsplash.com/@jane?utm_source=roamio',
  );

  testWidgets(
    'credits the photographer and opens their page (Unsplash terms)',
    (tester) async {
      final opened = <Uri>[];
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([bangkok]),
        banners: FakeBannerService({'TH': photo}),
        openedLinks: opened,
      );

      expect(find.text('Photo: Jane Doe · Unsplash'), findsOneWidget);
      await tester.tap(find.text('Photo: Jane Doe · Unsplash'));
      expect(opened, [Uri.parse(photo.photographerUrl)]);
      // The rest of the card still opens the adventure.
      await tester.tap(find.text('Bangkok'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Trip currency: THB'), findsOneWidget);
    },
  );

  testWidgets('without a banner the card shows the flag and no credit', (
    tester,
  ) async {
    await pumpRoamio(
      tester,
      FakeAuthService(initial: readyFacts),
      adventures: FakeAdventureService([bangkok]),
    );
    expect(find.text('🇹🇭'), findsOneWidget);
    expect(find.textContaining('Unsplash'), findsNothing);
  });

  testWidgets('an adventure with its own photo shows no Unsplash credit', (
    tester,
  ) async {
    final own = Adventure(
      id: 'own',
      name: 'Own photo trip',
      countryCode: 'TH',
      startDate: DateTime(2026, 10, 27),
      endDate: DateTime(2026, 11, 2),
      baseCurrency: 'THB',
      leaderUid: 'ari',
      memberUids: const ['ari'],
      bannerUrl: 'https://example.com/own.webp',
    );
    await pumpRoamio(
      tester,
      FakeAuthService(initial: readyFacts),
      adventures: FakeAdventureService([own]),
      banners: FakeBannerService({'TH': photo}),
    );
    expect(find.textContaining('Unsplash'), findsNothing);
  });
}
