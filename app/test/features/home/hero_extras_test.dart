import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_page.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_fx_repository.dart';
import '../../support/fake_home_card_memory.dart';
import '../../support/fake_invite_service.dart';
import '../../support/fake_sync.dart';
import '../../support/fake_tab_service.dart';

/// "Today" is 29 Oct 2026 in pumpRoamio. The tab fake keeps tabs under `bkk`.
Adventure _trip({
  List<String> members = const ['ari', 'ben'],
  String leader = 'ari',
  String currency = 'INR',
}) => Adventure(
  id: 'bkk',
  name: 'Goa trip',
  countryCode: 'IN',
  startDate: DateTime(2026, 10, 20),
  endDate: DateTime(2026, 11, 3),
  baseCurrency: currency,
  leaderUid: leader,
  memberUids: members,
);

TabEntry _tab(
  String id,
  String category,
  int minor, {
  TabStatus status = TabStatus.approved,
  String currency = 'INR',
}) => TabEntry(
  id: id,
  description: id,
  category: category,
  date: DateTime(2026, 10, 27),
  createdBy: 'ben',
  status: status,
  split: TabSplit(
    amount: Money(minor, currency),
    payers: [Payment('ben', minor)],
    participants: const ['ari', 'ben'],
    fxDate: '2026-10-27',
  ),
);

Future<void> _open(
  WidgetTester tester, {
  Adventure? adventure,
  List<TabEntry> tabs = const [],
  String as = 'ari',
  Map<String, String> rates = const {},
  FakeInviteService? invites,
  List<String>? shared,
  FakeConnectivity? connectivity,
}) => pumpRoamio(
  tester,
  FakeAuthService(
    initial: SessionFacts(uid: as, hasAccount: true, ageStatus: 'adult'),
  ),
  adventures: FakeAdventureService([adventure ?? _trip()]),
  tabs: FakeTabService(tabs),
  homeCardMemory: FakeHomeCardMemory(expanded: true),
  fx: FakeFxRepository(rates),
  invites: invites,
  shared: shared,
  connectivity: connectivity,
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('tabs waiting: a quick view for leads (spec UC-5)', () {
    final waiting = [
      _tab('w1', 'food_dining', 1000, status: TabStatus.waiting),
      _tab('w2', 'food_dining', 2000, status: TabStatus.waiting),
    ];

    testWidgets('a lead sees the count and it opens the tabs', (tester) async {
      await _open(tester, tabs: waiting);
      await _tap(tester, find.text('2 tabs waiting for approval'));
      expect(find.byType(AdventurePage), findsOneWidget);
    });

    testWidgets('a co-lead sees it too', (tester) async {
      await _open(
        tester,
        as: 'cara',
        adventure: Adventure(
          id: 'bkk',
          name: 'Goa trip',
          countryCode: 'IN',
          startDate: DateTime(2026, 10, 20),
          endDate: DateTime(2026, 11, 3),
          baseCurrency: 'INR',
          leaderUid: 'ari',
          coLeadUids: const ['cara'],
          memberUids: const ['ari', 'ben', 'cara'],
        ),
        tabs: [waiting.first],
      );
      expect(find.text('1 tab waiting for approval'), findsOneWidget);
    });

    testWidgets('a member doesn’t', (tester) async {
      await _open(tester, as: 'ben', tabs: waiting);
      expect(find.textContaining('waiting for approval'), findsNothing);
    });

    testWidgets('nothing waiting: nothing shown', (tester) async {
      await _open(tester, tabs: [_tab('a', 'food_dining', 1000)]);
      expect(find.textContaining('waiting for approval'), findsNothing);
    });
  });

  group('top category (spec UC-5)', () {
    testWidgets('the biggest, with its share', (tester) async {
      await _open(
        tester,
        tabs: [
          _tab('a', 'food_dining', 6000),
          _tab('b', 'shopping_souvenirs', 3000),
          _tab('c', 'incidentals', 1000),
        ],
      );
      expect(find.text('Most on Food & Dining · 60%'), findsOneWidget);
    });

    testWidgets('your own when you only have personal tabs', (tester) async {
      await _open(
        tester,
        tabs: [
          TabEntry(
            id: 'p',
            description: 'p',
            category: 'incidentals',
            date: DateTime(2026, 10, 27),
            createdBy: 'ari',
            status: TabStatus.personal,
            split: TabSplit(
              amount: Money(1000, 'INR'),
              payers: const [Payment('ari', 1000)],
              participants: const ['ari'],
              fxDate: '2026-10-27',
            ),
          ),
        ],
      );
      expect(find.text('Most on Incidentals · 100%'), findsOneWidget);
    });

    testWidgets('no tabs: nothing shown', (tester) async {
      await _open(tester);
      expect(find.textContaining('Most on'), findsNothing);
    });
  });

  group('exchange rate (spec UC-5)', () {
    test('picks a size that reads well, in whole numbers of minor units', () {
      final rates = FxRates(
        date: '2026-10-29',
        usdRates: const {'INR': '84', 'THB': '33.6', 'VND': '25000'},
      );
      final thb = rateExample(rates, from: 'THB', to: 'INR');
      expect((thb.units, thb.value), (1, Money(250, 'INR')));
      // One dong rounds to nothing, so it quotes a thousand.
      final vnd = rateExample(rates, from: 'VND', to: 'INR');
      expect((vnd.units, vnd.value), (1000, Money(336, 'INR')));
    });

    testWidgets('a foreign trip shows it', (tester) async {
      await _open(
        tester,
        adventure: _trip(currency: 'THB'),
        rates: const {'INR': '84', 'THB': '33.6'},
      );
      expect(find.text('1 THB = ₹2.50'), findsOneWidget);
    });

    testWidgets('in your own currency it isn’t there', (tester) async {
      await _open(tester, rates: const {'INR': '84', 'THB': '33.6'});
      expect(find.textContaining('='), findsNothing);
    });

    testWidgets('no rates yet: says so and offers to fetch them', (
      tester,
    ) async {
      await _open(tester, adventure: _trip(currency: 'THB'));
      expect(find.text('No exchange rate yet'), findsOneWidget);
      expect(find.text('Update rates'), findsOneWidget);
    });
  });

  group('invite shortcut (spec UC-5)', () {
    final solo = _trip(members: const ['ari']);

    testWidgets('a lead alone in the squad can share straight away', (
      tester,
    ) async {
      final shared = <String>[];
      await _open(tester, adventure: solo, shared: shared);
      await _tap(tester, find.text('Invite your squad'));
      expect(shared.single, contains('/i/'));
    });

    testWidgets('gone once someone has joined', (tester) async {
      await _open(tester);
      expect(find.text('Invite your squad'), findsNothing);
    });

    testWidgets('a member never sees it', (tester) async {
      await _open(
        tester,
        as: 'ben',
        adventure: _trip(members: const ['ben']),
      );
      expect(find.text('Invite your squad'), findsNothing);
    });

    testWidgets('offline it’s off, with the reason', (tester) async {
      final shared = <String>[];
      await _open(
        tester,
        adventure: solo,
        shared: shared,
        connectivity: FakeConnectivity(online: false),
      );
      await _tap(tester, find.text('Invite your squad'));
      expect(shared, isEmpty);
      expect(find.textContaining('Needs a connection'), findsOneWidget);
    });
  });

  testWidgets('all four fit a small phone', (tester) async {
    await _open(
      tester,
      adventure: _trip(members: const ['ari'], currency: 'THB'),
      rates: const {'INR': '84', 'THB': '33.6'},
      tabs: [
        _tab(
          'w',
          'food_dining',
          1000,
          status: TabStatus.waiting,
          currency: 'THB',
        ),
        _tab('a', 'activities_sightseeing', 90000000, currency: 'THB'),
      ],
    );
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
