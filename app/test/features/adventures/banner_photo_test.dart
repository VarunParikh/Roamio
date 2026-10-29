import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_photo_pipeline.dart';

Adventure _bangkok({String? bannerUrl}) => Adventure(
  id: 'bkk',
  name: 'Bangkok trip',
  countryCode: 'TH',
  startDate: DateTime(2026, 12),
  endDate: DateTime(2026, 12, 8),
  baseCurrency: 'THB',
  leaderUid: 'ari',
  memberUids: const ['ari'],
  bannerUrl: bannerUrl,
);

Future<(FakeAdventureService, FakePhotoPipeline)> _openEdit(
  WidgetTester tester, {
  String? bannerUrl,
}) async {
  final adventures = FakeAdventureService([_bangkok(bannerUrl: bannerUrl)]);
  final photos = FakePhotoPipeline();
  await pumpRoamio(
    tester,
    FakeAuthService(initial: readyFacts),
    adventures: adventures,
    photos: photos,
  );
  await tester.tap(find.text('Bangkok trip'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Edit adventure'));
  await tester.pumpAndSettle();
  return (adventures, photos);
}

void main() {
  group('own banner photo (UC-10, Task 21b)', () {
    testWidgets('a lead picks a photo; it is queued as the banner', (
      tester,
    ) async {
      final (_, photos) = await _openEdit(tester);

      await tester.tap(find.text('Use my own photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();

      expect(photos.picks, [false]);
      expect(photos.queued, [
        '/photos/1.jpg -> adventures/bkk/banner (adventures/bkk.bannerUrl replace)',
      ]);
      expect(find.textContaining('appear once it’s uploaded'), findsOneWidget);
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      final (_, photos) = await _openEdit(tester);
      photos.cancelNext = true;
      await tester.tap(find.text('Use my own photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();
      expect(photos.queued, isEmpty);
    });

    testWidgets('an own photo can go back to the country photo', (
      tester,
    ) async {
      final (adventures, _) = await _openEdit(
        tester,
        bannerUrl: 'https://firebasestorage.googleapis.com/o/b.webp',
      );

      expect(find.text('Use my own photo'), findsNothing);
      await tester.tap(find.text('Use country photo'));
      await tester.pumpAndSettle();
      expect(adventures.bannerResets, ['bkk']);
      expect(find.text('Use my own photo'), findsOneWidget);
    });

    testWidgets('without an own photo there is nothing to reset', (
      tester,
    ) async {
      await _openEdit(tester);
      expect(find.text('Use country photo'), findsNothing);
    });
  });
}
