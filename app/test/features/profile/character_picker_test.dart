import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/profile/data/profile_service.dart';

import '../../support/fake_auth_service.dart';
import '../../support/fake_profile_service.dart';

const _choose = 'Choose your character';

Future<void> _openYou(
  WidgetTester tester,
  FakeProfileService profile, {
  bool phase2 = false,
}) async {
  await pumpRoamio(
    tester,
    FakeAuthService(initial: readyFacts),
    profile: profile,
    phase2: phase2,
  );
  await tester.tap(find.text('You'));
  await tester.pumpAndSettle();
}

Finder _assetImage(String id) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == 'assets/characters/$id.webp',
);

void main() {
  group('You page, pilot', () {
    testWidgets('no photo can be uploaded', (tester) async {
      await _openYou(tester, FakeProfileService());

      expect(find.byTooltip('Change photo'), findsNothing);
      expect(find.byTooltip(_choose), findsOneWidget);
    });

    testWidgets('choosing a character saves it and shows it', (tester) async {
      final profile = FakeProfileService();
      await _openYou(tester, profile);

      await tester.tap(find.byTooltip(_choose));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Astronaut'));
      await tester.pumpAndSettle();

      expect(profile.characterSaved, ['astronaut']);
      expect(_assetImage('astronaut'), findsOneWidget);
    });

    testWidgets('the picker covers the bottom bar', (tester) async {
      await _openYou(tester, FakeProfileService());

      await tester.tap(find.byTooltip(_choose));
      await tester.pumpAndSettle();
      final home = tester.getCenter(find.text('Home'));
      await tester.tapAt(home);
      await tester.pumpAndSettle();

      // The tap lands on the sheet, so the tabs don't change underneath it.
      expect(find.text('Your profile'), findsOneWidget);
    });

    testWidgets('closing the picker changes nothing', (tester) async {
      final profile = FakeProfileService();
      await _openYou(tester, profile);

      await tester.tap(find.byTooltip(_choose));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(profile.characterSaved, isEmpty);
    });

    testWidgets('your current character is marked in the picker', (
      tester,
    ) async {
      await _openYou(
        tester,
        FakeProfileService(
          profile: const Profile(name: 'Ari', characterId: 'robot'),
        ),
      );

      await tester.tap(find.byTooltip(_choose));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Robot' &&
              (w.properties.selected ?? false),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Alien' &&
              (w.properties.selected ?? false),
        ),
        findsNothing,
      );
    });

    testWidgets('with no character you see your initial', (tester) async {
      await _openYou(
        tester,
        FakeProfileService(profile: const Profile(name: 'Ari')),
      );

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('an id this version doesn’t know shows your initial', (
      tester,
    ) async {
      await _openYou(
        tester,
        FakeProfileService(
          profile: const Profile(name: 'Ari', characterId: 'from_the_future'),
        ),
      );

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('a stored photo link is never loaded', (tester) async {
      await _openYou(
        tester,
        FakeProfileService(
          profile: const Profile(
            name: 'Ari',
            photoUrl: 'https://example.com/me.jpg',
          ),
        ),
      );

      final avatars = tester.widgetList<CircleAvatar>(
        find.byType(CircleAvatar),
      );
      expect(
        avatars.map((a) => a.backgroundImage),
        isNot(contains(isA<CachedNetworkImageProvider>())),
      );
    });
  });

  group('You page, with Phase 2 uploads on', () {
    testWidgets('both ways are offered', (tester) async {
      await _openYou(tester, FakeProfileService(), phase2: true);

      expect(find.byTooltip('Change photo'), findsOneWidget);
      expect(find.byTooltip(_choose), findsOneWidget);
    });
  });

  group('Home asks once', () {
    Future<void> openHome(WidgetTester tester, FakeProfileService profile) =>
        pumpRoamio(
          tester,
          FakeAuthService(initial: readyFacts),
          profile: profile,
          phase2: false,
        );

    const notAsked = Profile(name: 'Ari', characterOffered: false);

    testWidgets('a new account is offered a character', (tester) async {
      await openHome(tester, FakeProfileService(profile: notAsked));

      expect(find.text('Pick your character'), findsOneWidget);
    });

    testWidgets('Not now is remembered, and sets no character', (tester) async {
      final profile = FakeProfileService(profile: notAsked);
      await openHome(tester, profile);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(profile.characterSaved, [null]);
      expect(find.text('Pick your character'), findsNothing);
    });

    testWidgets('Choose opens the picker and saves the pick', (tester) async {
      final profile = FakeProfileService(profile: notAsked);
      await openHome(tester, profile);

      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Robot'));
      await tester.pumpAndSettle();

      expect(profile.characterSaved, ['robot']);
      expect(find.text('Pick your character'), findsNothing);
    });

    testWidgets('someone already asked isn’t asked again', (tester) async {
      await openHome(tester, FakeProfileService());

      expect(find.text('Pick your character'), findsNothing);
    });
  });
}
