import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_format.dart';
import 'package:roamio/features/adventures/ui/adventure_page.dart';
import 'package:roamio/features/banners/data/banner_service.dart';
import 'package:roamio/features/banners/ui/adventure_banner.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/squad/ui/person.dart';
import 'package:roamio/features/tabs/ui/add_tab_screen.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_banner_service.dart';
import '../../support/fake_squad_service.dart';

/// "Today" is 29 Oct 2026 in pumpRoamio.
Adventure _trip(
  DateTime start,
  DateTime end, {
  String name = 'Goa trip',
  List<String> members = const ['ari'],
}) => Adventure(
  id: 'goa',
  name: name,
  countryCode: 'IN',
  city: 'Panaji',
  startDate: start,
  endDate: end,
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: members,
);

void main() {
  group('the wording on the card (spec UC-5)', () {
    final today = DateTime(2026, 10, 29);

    test('current: the badge and days left', () {
      final a = _trip(DateTime(2026, 10, 20), DateTime(2026, 11, 3));
      expect(heroBadge(a, today), 'Current adventure');
      expect(heroCountdown(a, today), '5 days left');
    });

    test('current: the last day', () {
      final a = _trip(DateTime(2026, 10, 20), DateTime(2026, 10, 29));
      expect(heroCountdown(a, today), 'Last day');
    });

    test('next: the badge and days until it starts', () {
      final a = _trip(DateTime(2026, 11, 10), DateTime(2026, 11, 12));
      expect(heroBadge(a, today), 'Next adventure');
      expect(heroCountdown(a, today), 'Starts in 12 days');
    });

    test('next: tomorrow', () {
      final a = _trip(DateTime(2026, 10, 30), DateTime(2026, 11, 2));
      expect(heroCountdown(a, today), 'Starts tomorrow');
    });
  });

  group('the adventure card (spec UC-5)', () {
    final current = _trip(DateTime(2026, 10, 20), DateTime(2026, 11, 3));

    testWidgets('current version: badge, dates, days left', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([current]),
      );
      expect(find.text('CURRENT ADVENTURE'), findsOneWidget);
      expect(find.text('20 Oct – 3 Nov 2026 · 5 days left'), findsOneWidget);
    });

    testWidgets('next version: starts in, and Add tab still there', (
      tester,
    ) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([
          _trip(DateTime(2026, 11, 10), DateTime(2026, 11, 12)),
        ]),
      );
      expect(find.text('NEXT ADVENTURE'), findsOneWidget);
      expect(find.text('10 – 12 Nov 2026 · Starts in 12 days'), findsOneWidget);
      expect(find.text('Add tab'), findsOneWidget);
    });

    testWidgets('tapping the card opens the adventure', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([current]),
      );
      await tester.tap(find.text('Goa trip'));
      await tester.pumpAndSettle();
      expect(find.byType(AdventurePage), findsOneWidget);
    });

    testWidgets('Add tab goes straight to adding a tab', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([current]),
      );
      await tester.tap(find.text('Add tab'));
      await tester.pumpAndSettle();
      expect(find.byType(AddTabScreen), findsOneWidget);
    });

    testWidgets('squad pictures: first 4 then +N, pals included', (
      tester,
    ) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([
          _trip(
            DateTime(2026, 10, 20),
            DateTime(2026, 11, 3),
            members: const ['ari', 'ben', 'cara', 'dan'],
          ),
        ]),
        squad: FakeSquadService()
          ..palsByAdventure['goa'] = const [
            Pal(id: 'kiko', nickname: 'Kiko'),
            Pal(id: 'lulu', nickname: 'Lulu'),
          ],
      );
      expect(find.byType(PersonAvatar), findsNWidgets(4));
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('the photographer’s credit sits bottom-left', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([current]),
        banners: FakeBannerService(const {
          'IN': BannerPhoto(
            url: 'https://example.com/p.jpg',
            photographer: 'Asha',
            photographerUrl: 'https://example.com/asha',
          ),
        }),
      );
      final credit = tester.getTopLeft(find.byType(BannerCredit));
      final card = tester.getRect(find.byType(AdventureBanner));
      expect(credit.dx - card.left, lessThan(card.width / 4));
      expect(credit.dy, greaterThan(card.center.dy));
    });

    testWidgets('a long name fits a small phone at large text', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([
          _trip(
            DateTime(2026, 10, 20),
            DateTime(2026, 11, 3),
            name: 'The very long college reunion trip around the whole of Goa',
            members: const ['ari', 'ben', 'cara', 'dan', 'eli', 'fay'],
          ),
        ]),
      );
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
