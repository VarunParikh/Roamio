import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/features/adventures/data/activity_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';

import '../../support/fake_activity_service.dart';
import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_photo_pipeline.dart';
import '../../support/fake_tab_service.dart';

/// Spec §12: no dead ends. Each empty or error state has one next action.
/// The full list is in `tasks/screen_states.md`.
final _goa = Adventure(
  id: 'bkk',
  name: 'Goa trip',
  countryCode: 'IN',
  startDate: DateTime(2026, 10, 20),
  endDate: DateTime(2026, 11, 2),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari'],
);

Future<void> _go(WidgetTester tester, String location) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home: adventures can’t load → Try again', (tester) async {
    final adventures = FakeAdventureService([_goa])..failToLoad = true;
    await pumpRoamio(
      tester,
      FakeAuthService(initial: readyFacts),
      adventures: adventures,
    );

    expect(find.text('We couldn’t load your adventures.'), findsOneWidget);
    adventures.failToLoad = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Goa trip'), findsOneWidget);
  });

  group('adventure you can no longer see: one way back', () {
    for (final path in [
      '/adventures/gone',
      '/adventures/gone/tabs/t1',
      '/adventures/gone/tabs/new',
      '/adventures/gone/edit',
    ]) {
      testWidgets(path, (tester) async {
        await pumpRoamio(
          tester,
          FakeAuthService(initial: readyFacts),
          adventures: FakeAdventureService([_goa]),
        );
        await _go(tester, path);

        expect(find.text('This adventure isn’t available.'), findsOneWidget);
        await tester.tap(find.text('Back to Home'));
        await tester.pumpAndSettle();
        expect(find.text('Goa trip'), findsOneWidget);
      });
    }
  });

  testWidgets('Split: the split can’t be worked out → Try again', (
    tester,
  ) async {
    final tabs = FakeTabService()..failToLoad = true;
    await pumpRoamio(
      tester,
      FakeAuthService(initial: readyFacts),
      adventures: FakeAdventureService([_goa]),
      tabs: tabs,
    );
    await tester.tap(find.text('Split'));
    await tester.pumpAndSettle();

    expect(find.text('We couldn’t work out the split.'), findsOneWidget);
    tabs.failToLoad = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('We couldn’t work out the split.'), findsNothing);
  });

  testWidgets('Split with no adventures → New Adventure', (tester) async {
    await pumpRoamio(tester, FakeAuthService(initial: readyFacts));
    await tester.tap(find.text('Split'));
    await tester.pumpAndSettle();

    expect(
      find.text('No adventures yet, so nothing to split.'),
      findsOneWidget,
    );
    await tester.tap(find.text('New Adventure'));
    await tester.pumpAndSettle();
    expect(find.text('No adventures yet, so nothing to split.'), findsNothing);
  });

  testWidgets('You: a photo that can’t be read says so', (tester) async {
    final photos = FakePhotoPipeline()..unreadable = true;
    await pumpRoamio(
      tester,
      FakeAuthService(initial: readyFacts),
      photos: photos,
    );
    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Change photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();

    expect(
      find.text('That photo couldn’t be read. Try another.'),
      findsOneWidget,
    );
  });

  group('Activity', () {
    testWidgets('empty → back to the adventure', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_goa]),
      );
      await _go(tester, '/adventures/bkk');
      await _go(tester, '/adventures/bkk/activity');

      expect(find.text('Nothing has happened yet.'), findsOneWidget);
      await tester.tap(find.text('Back to the adventure'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing has happened yet.'), findsNothing);
    });

    testWidgets('can’t load → Try again', (tester) async {
      final activity = _FailingActivity();
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_goa]),
        activity: activity,
      );
      await _go(tester, '/adventures/bkk/activity');

      expect(find.text('We couldn’t load the activity.'), findsOneWidget);
      activity.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing has happened yet.'), findsOneWidget);
    });
  });
}

class _FailingActivity extends FakeActivityService {
  bool fail = true;

  @override
  Stream<List<ActivityEntry>> recent(String adventureId) =>
      fail ? Stream.error(Exception('offline')) : super.recent(adventureId);
}
