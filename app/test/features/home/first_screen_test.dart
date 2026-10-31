import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/home/ui/first_screen_cards.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_invite_service.dart';
import '../../support/fake_notification_service.dart';

Adventure _trip(String id, DateTime start, DateTime end) => Adventure(
  id: id,
  name: 'Trip $id',
  countryCode: 'IN',
  startDate: start,
  endDate: end,
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari'],
);

double _channel(double c) {
  final v = c / 255;
  return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(double r, double g, double b) =>
    0.2126 * _channel(r) + 0.7152 * _channel(g) + 0.0722 * _channel(b);

void main() {
  splashPhoto();

  group('the destination photos (spec UC-6)', () {
    test('there are 10 and each one is bundled', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      expect(destinationPhotos.length, 10);
      for (final path in destinationPhotos) {
        final bytes = await rootBundle.load(path);
        expect(bytes.lengthInBytes, greaterThan(1000), reason: path);
      }
    });

    test('a new pick per app open, the same until then', () {
      final seen = <String>{};
      for (var i = 0; i < 80; i++) {
        final open = ProviderContainer();
        addTearDown(open.dispose);
        final pick = open.read(destinationPhotoProvider);
        expect(open.read(destinationPhotoProvider), pick);
        expect(destinationPhotos, contains(pick));
        seen.add(pick);
      }
      expect(seen.length, greaterThan(1));
    });

    testWidgets('white text passes 4.5:1 on every pixel of all 10', (
      tester,
    ) async {
      await tester.runAsync(() async {
        const ink = RoamioColors.ink;
        final inkR = ink.r * 255;
        final inkG = ink.g * 255;
        final inkB = ink.b * 255;
        for (final path in destinationPhotos) {
          final data = await rootBundle.load(path);
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
            targetWidth: 200,
          );
          final frame = await codec.getNextFrame();
          final raw = await frame.image.toByteData();
          final pixels = raw!.buffer.asUint8List();
          var worst = double.infinity;
          for (var i = 0; i + 3 < pixels.length; i += 4) {
            const a = planCardTextScrimAlpha;
            final l = _luminance(
              pixels[i] * (1 - a) + inkR * a,
              pixels[i + 1] * (1 - a) + inkG * a,
              pixels[i + 2] * (1 - a) + inkB * a,
            );
            worst = min(worst, 1.05 / (l + 0.05));
          }
          expect(worst, greaterThanOrEqualTo(4.5), reason: path);
        }
      });
    });
  });

  group('nothing ahead (spec UC-6)', () {
    testWidgets('no adventures: image card, then No adventures yet', (
      tester,
    ) async {
      await pumpRoamio(tester, FakeAuthService(initial: readyFacts));

      expect(find.text('Plan your next adventure'), findsOneWidget);
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.label, 'Create a new adventure');
      expect(button.pulse, isTrue);
      expect(find.text('No adventures yet'), findsOneWidget);
      expect(find.text('New adventure'), findsNothing);
      expect(
        tester.getTopLeft(find.text('No adventures yet')).dy,
        greaterThan(tester.getTopLeft(find.byType(PrimaryButton)).dy),
      );
    });

    testWidgets('past trips only: image card, then the Past list', (
      tester,
    ) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([
          _trip('old', DateTime(2026, 6), DateTime(2026, 6, 5)),
        ]),
      );
      expect(find.text('Plan your next adventure'), findsOneWidget);
      expect(find.text('No adventures yet'), findsNothing);
      expect(find.text('Past adventures (1)'), findsOneWidget);
      expect(find.text('New adventure'), findsNothing);
    });

    testWidgets('with something ahead: a plain button, no image card', (
      tester,
    ) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([
          _trip('next', DateTime(2026, 12), DateTime(2026, 12, 5)),
        ]),
      );
      expect(find.text('Plan your next adventure'), findsNothing);
      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.text('New adventure'), findsOneWidget);
    });

    testWidgets('only invites sit above the card; other prompts below', (
      tester,
    ) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        invites: FakeInviteService()..saved.add('7KQ2M9XA'),
        adventures: FakeAdventureService([
          _trip('old', DateTime(2026, 6), DateTime(2026, 6, 5)),
        ]),
        notifications: FakeNotificationService(),
      );
      final card = tester.getTopLeft(find.text('Plan your next adventure')).dy;
      expect(tester.getTopLeft(find.text('Invites')).dy, lessThan(card));
      final prompt = find.text('Know when friends join');
      await tester.ensureVisible(prompt);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(prompt).dy,
        greaterThan(tester.getTopLeft(find.byType(PrimaryButton)).dy),
      );
    });

    testWidgets('fits a small phone', (tester) async {
      await pumpRoamio(tester, FakeAuthService(initial: readyFacts));
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

void splashPhoto() {
  test('the splash photo never matches the plan card’s', () {
    final seen = <String>{};
    for (var i = 0; i < 200; i++) {
      final open = ProviderContainer();
      addTearDown(open.dispose);
      final splash = open.read(splashPhotoProvider);
      expect(splash, isNot(open.read(destinationPhotoProvider)));
      expect(destinationPhotos, contains(splash));
      expect(open.read(splashPhotoProvider), splash);
      seen.add(splash);
    }
    expect(seen.length, greaterThan(1));
  });

  group('the splash photo’s pan', () {
    Future<void> pump(WidgetTester tester, {bool reduced = false}) =>
        tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: const PanningPhoto(
                  photo: 'assets/destinations/paris.webp',
                ),
              ),
            ),
          ),
        );

    double alignment(WidgetTester tester) =>
        (tester.widget<Image>(find.byType(Image)).alignment as Alignment).x;

    testWidgets('moves slowly from left to right', (tester) async {
      await pump(tester);
      expect(alignment(tester), -1);

      await tester.pump(const Duration(seconds: 12));
      final later = alignment(tester);
      expect(later, greaterThan(-1));
      expect(later, lessThan(-0.7)); // Very slow: a tenth of the way.

      await tester.pump(PanningPhoto.sweep - const Duration(seconds: 12));
      expect(alignment(tester), closeTo(1, 0.01));
    });

    testWidgets('holds still for people who ask for reduced motion', (
      tester,
    ) async {
      await pump(tester, reduced: true);
      await tester.pump(const Duration(seconds: 30));
      expect(alignment(tester), 0);
    });
  });
}
