import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_location_service.dart';
import '../../support/fake_photo_pipeline.dart';
import '../../support/fake_profile_service.dart';
import '../../support/fake_squad_service.dart';
import '../../support/fake_tab_service.dart';

final _bangkok = Adventure(
  id: 'bkk',
  name: 'Bangkok trip',
  countryCode: 'TH',
  startDate: DateTime(2026, 10, 10),
  endDate: DateTime(2026, 11, 2),
  baseCurrency: 'THB',
  leaderUid: 'ari',
  memberUids: const ['ari', 'mia'],
);

class _Harness {
  final tabs = FakeTabService();
  final photos = FakePhotoPipeline();
  late FakeLocationService location;
}

Future<_Harness> _openAddTab(
  WidgetTester tester, {
  String ageStatus = 'adult',
  String uid = 'ari',
  List<LocationResult>? locations,
  bool locationOn = true,
}) async {
  final h = _Harness()..location = FakeLocationService(locations);
  await pumpRoamio(
    tester,
    FakeAuthService(
      initial: SessionFacts(uid: uid, hasAccount: true, ageStatus: ageStatus),
    ),
    adventures: FakeAdventureService([_bangkok]),
    squad: FakeSquadService(),
    tabs: h.tabs,
    photos: h.photos,
    location: h.location,
    profile: FakeProfileService(location: locationOn),
  );
  await tester.tap(find.text('Bangkok trip'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Add tab'), 200);
  await _tap(tester, find.text('Add tab'));
  await tester.enterText(find.widgetWithText(TextField, 'Amount'), '900');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  await _tap(tester, find.textContaining('Food & Dining'));
  return h;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _addPhoto(WidgetTester tester, {bool camera = false}) async {
  await _tap(tester, find.text('Add photo'));
  await tester.tap(find.text(camera ? 'Take a photo' : 'Choose from gallery'));
  await tester.pumpAndSettle();
}

void main() {
  group('memories (UC-21: up to 4 photos)', () {
    testWidgets('adds up to 4 photos and queues them for the tab', (
      tester,
    ) async {
      final h = await _openAddTab(tester);

      await _addPhoto(tester, camera: true);
      for (var i = 0; i < 3; i++) {
        await _addPhoto(tester);
      }
      expect(h.photos.picks, [true, false, false, false]);
      expect(find.byTooltip('Remove photo'), findsNWidgets(4));

      // A fifth is refused.
      final add = find.widgetWithText(OutlinedButton, 'Add photo');
      await tester.ensureVisible(add);
      expect(tester.widget<OutlinedButton>(add).onPressed, isNull);
      expect(find.text('Up to 4 photos per tab.'), findsOneWidget);

      await _tap(tester, find.text('Save tab'));
      const tab = 'adventures/bkk/tabs/tab0';
      expect(h.photos.queued, [
        for (var i = 1; i <= 4; i++)
          '/photos/$i.jpg -> $tab ($tab.memories append)',
      ]);
    });

    testWidgets('a photo can be removed before saving', (tester) async {
      final h = await _openAddTab(tester);
      await _addPhoto(tester);
      await _addPhoto(tester);

      await _tap(tester, find.byTooltip('Remove photo').first);
      expect(find.byTooltip('Remove photo'), findsOneWidget);

      await _tap(tester, find.text('Save tab'));
      expect(h.photos.queued.single, startsWith('/photos/2.jpg'));
    });

    testWidgets('cancelling the picker adds nothing', (tester) async {
      final h = await _openAddTab(tester);
      h.photos.cancelNext = true;
      await _addPhoto(tester);
      expect(find.byTooltip('Remove photo'), findsNothing);
    });
  });

  group('location (UC-21, never for minors)', () {
    testWidgets('an adult adds where it happened', (tester) async {
      final h = await _openAddTab(tester);

      await _tap(tester, find.text('Add location'));
      expect(find.text('📍 13.7563, 100.5018'), findsOneWidget);
      await _tap(tester, find.text('Save tab'));

      final saved = h.tabs.added.single.$2.location!;
      expect((saved.lat, saved.lng), (13.7563, 100.5018));
    });

    testWidgets(
      'with the Location switch off, Add location turns it on and asks',
      (tester) async {
        final h = await _openAddTab(tester, locationOn: false);

        // Asked only when they choose to add one.
        expect(h.location.calls, isEmpty);
        await tester.ensureVisible(find.text('Add location'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add location'));
        await tester.pumpAndSettle();
        expect(h.location.calls, isNotEmpty);
        expect(find.text('📍 13.7563, 100.5018'), findsOneWidget);
      },
    );

    testWidgets('a minor never gets it, even with a stored “on”', (
      tester,
    ) async {
      await _openAddTab(tester, ageStatus: 'minor_active', uid: 'mia');

      expect(find.text('Add location'), findsNothing);
      expect(find.textContaining('Location is off'), findsNothing);
    });

    testWidgets('offers to switch location services on', (tester) async {
      final h = await _openAddTab(
        tester,
        locations: const [LocationServicesOff()],
      );

      await _tap(tester, find.text('Add location'));
      expect(find.text('Turn on location services'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(h.location.calls, ['current', 'locationSettings']);

      // Back from settings, trying again works.
      await _tap(tester, find.text('Add location'));
      expect(find.text('📍 13.7563, 100.5018'), findsOneWidget);
    });

    testWidgets('explains a refused permission and points to settings', (
      tester,
    ) async {
      final h = await _openAddTab(
        tester,
        locations: const [LocationDenied(forever: true)],
      );

      await _tap(tester, find.text('Add location'));
      expect(find.textContaining('Location is off for Roamio'), findsOne);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(h.location.calls.last, 'appSettings');
      expect(find.text('📍 13.7563, 100.5018'), findsNothing);
    });

    testWidgets('a location can be removed again', (tester) async {
      final h = await _openAddTab(tester);
      await _tap(tester, find.text('Add location'));
      await _tap(tester, find.byTooltip('Remove location'));
      expect(find.text('Add location'), findsOneWidget);

      await _tap(tester, find.text('Save tab'));
      expect(h.tabs.added.single.$2.location, isNull);
    });

    testWidgets('minors never see it (spec §7.2)', (tester) async {
      final h = await _openAddTab(
        tester,
        uid: 'mia',
        ageStatus: 'minor_active',
      );
      expect(find.text('Add location'), findsNothing);
      expect(h.location.calls, isEmpty);
      // Photos are still fine.
      expect(find.text('Add photo'), findsOneWidget);
    });
  });
}
