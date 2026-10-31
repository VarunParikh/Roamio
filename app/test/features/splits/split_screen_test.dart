import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/splits/ui/split_charts.dart';
import 'package:roamio/features/splits/ui/who_pays_whom.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/squad/ui/person.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';
import 'package:roamio/features/tabs/ui/tabs_section.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_fx_repository.dart';
import '../../support/fake_squad_service.dart';
import '../../support/fake_tab_service.dart';

/// Happening now (today is 29 Oct 2026): Ari leads, Ben is a member, Kiko
/// is a pal.
Adventure _goa({DateTime? end}) => Adventure(
  id: 'bkk',
  name: 'Goa trip',
  countryCode: 'IN',
  startDate: DateTime(2026, 10, 20),
  endDate: end ?? DateTime(2026, 11, 2),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari', 'ben'],
);

/// Spec §6 worked example.
final _dinner = TabEntry(
  id: 't1',
  description: 'Dinner',
  category: 'food_dining',
  date: DateTime(2026, 10, 27),
  createdBy: 'ari',
  split: TabSplit(
    amount: Money(300000, 'INR'),
    payers: const [Payment('ari', 200000), Payment('ben', 100000)],
    participants: const ['ari', 'ben', 'kiko'],
    percentBp: const {'ari': 5000, 'ben': 2500, 'kiko': 2500},
    fxDate: '2026-10-27',
  ),
);

ValueKey<String> _row(String from, String to) => ValueKey('transfer-$from-$to');

Finder _arrowOn(String from, String to) => find.descendant(
  of: find.byKey(_row(from, to)),
  matching: find.byIcon(Icons.chevron_right),
);

/// A ₹[minor] tab of [status], paid by [paidBy] and shared by [among].
TabEntry _tab(
  String id,
  int minor, {
  required String paidBy,
  required List<String> among,
  TabStatus status = TabStatus.approved,
  String currency = 'INR',
}) => TabEntry(
  id: id,
  description: id,
  category: 'food_dining',
  date: DateTime(2026, 10, 27),
  createdBy: paidBy,
  status: status,
  split: TabSplit(
    amount: Money(minor, currency),
    payers: [Payment(paidBy, minor)],
    participants: among,
    fxDate: '2026-10-27',
  ),
);

Future<void> _openSplit(
  WidgetTester tester, {
  String as = 'ari',
  Adventure? adventure,
  List<TabEntry>? tabs,
  String currency = 'INR',
  Map<String, String> rates = const {},
  FakeSquadService? squad,
  bool exportEnabled = true,
}) async {
  await pumpRoamio(
    tester,
    FakeAuthService(
      initial: SessionFacts(uid: as, hasAccount: true, ageStatus: 'adult'),
    ),
    adventures: FakeAdventureService([adventure ?? _goa()]),
    tabs: FakeTabService(tabs ?? [_dinner]),
    squad: (squad ?? FakeSquadService())
      ..names.addAll({'ari': 'Ari Chen', 'ben': 'Ben Roy'})
      ..palsByAdventure['bkk'] = [const Pal(id: 'kiko', nickname: 'Kiko')],
    fx: FakeFxRepository(rates),
    profileCurrency: currency,
    exportEnabled: exportEnabled,
  );
  await tester.tap(find.text('Split'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('Split screen (spec UC-24, UC-25, worked example §6)', () {
    testWidgets('opens on the active adventure with the headline first', (
      tester,
    ) async {
      await _openSplit(tester);

      expect(find.text('₹1,500.00 spent by you'), findsOneWidget);
      expect(find.text('You’re owed ₹500.00'), findsOneWidget);
      // Who pays whom is always there; the rest on request.
      expect(find.text('Who pays whom'), findsOneWidget);
      expect(find.byKey(_row('kiko', 'ari')), findsOneWidget);
      expect(find.byKey(_row('kiko', 'ben')), findsOneWidget);
      expect(find.text('Balances'), findsNothing);

      expect(find.text('pays ₹500.00'), findsOneWidget);
      expect(find.text('pays ₹250.00'), findsOneWidget);

      await _tap(tester, find.text('See detailed breakdown'));
      expect(find.text('+₹250.00'), findsOneWidget); // Ben's balance
      expect(find.text('-₹750.00'), findsOneWidget); // Kiko's balance
      expect(find.text('Food & Dining'), findsWidgets);
      expect(find.text('Tue, 27 Oct 2026 · ₹3,000.00'), findsOneWidget);
    });

    testWidgets('someone who left keeps their name; a deleted account '
        'shows as Deleted user (spec §8)', (tester) async {
      final squad = FakeSquadService()
        ..names['dan'] = 'Dan Lee'
        ..deleted.add('zed');
      final taxi = TabEntry(
        id: 't2',
        description: 'Taxi',
        category: 'local_transportation',
        date: DateTime(2026, 10, 28),
        createdBy: 'dan',
        split: TabSplit(
          amount: Money(90000, 'INR'),
          payers: const [Payment('dan', 60000), Payment('zed', 30000)],
          participants: const ['ari', 'dan', 'zed'],
          fxDate: '2026-10-28',
        ),
      );
      await _openSplit(tester, tabs: [taxi], squad: squad);

      await _tap(tester, find.text('See detailed breakdown'));
      expect(find.textContaining('Dan Lee'), findsWidgets);
      expect(find.textContaining('Deleted user'), findsWidgets);
      expect(find.textContaining('Left'), findsNothing);
      // Squad members' names load as before; only the others are looked up.
      expect(squad.lookups.map((l) => l.join(',')), contains('dan,zed'));
    });

    testWidgets('each person sees their own headline', (tester) async {
      await _openSplit(tester, as: 'ben');
      expect(find.text('You’re owed ₹250.00'), findsOneWidget);
    });

    testWidgets('amounts show in the viewer’s currency (UC-26)', (
      tester,
    ) async {
      await _openSplit(
        tester,
        currency: 'THB',
        rates: const {'INR': '84', 'THB': '35'},
      );
      // ₹500 at 84 INR and 35 THB per USD.
      expect(find.text('You’re owed ฿208.34'), findsOneWidget);

      // The menu switches the figures to the trip's currency, and back.
      await _tap(tester, find.byTooltip('More options'));
      await _tap(tester, find.text('Show in INR'));
      expect(find.text('You’re owed ₹500.00'), findsOneWidget);
      expect(find.text('₹1,500.00 spent by you'), findsOneWidget);
      await _tap(tester, find.byTooltip('More options'));
      await _tap(tester, find.text('Show in THB'));
      expect(find.text('You’re owed ฿208.34'), findsOneWidget);
    });

    testWidgets('without rates it shows the trip currency and says so', (
      tester,
    ) async {
      await _openSplit(tester, currency: 'THB');
      expect(find.text('You’re owed ₹500.00'), findsOneWidget);
      expect(
        find.text('Shown in INR: exchange rates aren’t available yet.'),
        findsOneWidget,
      );
    });

    testWidgets('no tabs: all square, with a way to add one', (tester) async {
      await _openSplit(tester, tabs: const []);
      expect(find.text('All square 🎉'), findsOneWidget);
      expect(find.text('No tabs yet in Goa trip.'), findsOneWidget);
      expect(find.text('Open adventure'), findsOneWidget);
    });

    testWidgets('the budget sits inside the top card', (tester) async {
      await _openSplit(tester);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('₹1,500.00 spent by you'),
            matching: find.byType(Card),
          ),
          matching: find.text('Set a budget'),
        ),
        findsOneWidget,
      );
    });

    group('Who pays whom', () {
      testWidgets('a lead can act on a pal’s rows and their own', (
        tester,
      ) async {
        await _openSplit(tester);
        expect(_arrowOn('kiko', 'ari'), findsOneWidget);
        expect(_arrowOn('kiko', 'ben'), findsOneWidget);
      });

      testWidgets('a member can act only on their own rows', (tester) async {
        await _openSplit(tester, as: 'ben');
        expect(_arrowOn('kiko', 'ben'), findsOneWidget);
        expect(_arrowOn('kiko', 'ari'), findsNothing);

        // Tapping a display-only row does nothing.
        await _tap(tester, find.byKey(_row('kiko', 'ari')));
        expect(find.textContaining('No money moves in Roamio'), findsNothing);
      });

      testWidgets('someone not in a row, and not a lead, can’t act on it', (
        tester,
      ) async {
        final trip = Adventure(
          id: 'bkk',
          name: 'Goa trip',
          countryCode: 'IN',
          startDate: DateTime(2026, 10, 20),
          endDate: DateTime(2026, 11, 2),
          baseCurrency: 'INR',
          leaderUid: 'ari',
          memberUids: const ['ari', 'ben', 'cara'],
        );
        await _openSplit(
          tester,
          as: 'ben',
          adventure: trip,
          tabs: [
            _tab('t', 100000, paidBy: 'ari', among: ['ari', 'cara']),
          ],
        );
        expect(find.byKey(_row('cara', 'ari')), findsOneWidget);
        expect(_arrowOn('cara', 'ari'), findsNothing);
      });

      testWidgets('rows show pictures and TalkBack reads the whole payment', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _openSplit(tester);
        expect(
          find.descendant(
            of: find.byKey(_row('kiko', 'ari')),
            matching: find.byType(PersonAvatar),
          ),
          findsNWidgets(2),
        );
        expect(
          find.bySemanticsLabel('Kiko pays you ₹500.00. Mark as settled'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Kiko pays Ben Roy ₹250.00. Mark as settled'),
          findsOneWidget,
        );
        semantics.dispose();
      });

      final everyone = ['ari', 'ben', 'p1', 'p2', 'p3', 'p4', 'p5'];
      final squad = FakeSquadService();

      testWidgets('first 4, then View all; your own rows come first', (
        tester,
      ) async {
        await _openSplit(
          tester,
          as: 'ben',
          tabs: [
            _tab('big', 700000, paidBy: 'ari', among: everyone),
            _tab('small', 10000, paidBy: 'ben', among: ['ben', 'p5']),
          ],
          squad: squad,
        );
        // Ben owes least, but his is the row he can act on, so it's on top.
        expect(find.byType(TransferRow), findsNWidgets(4));
        expect(
          tester.getTopLeft(find.byKey(_row('ben', 'ari'))).dy,
          lessThan(tester.getTopLeft(find.byType(TransferRow).at(1)).dy),
        );

        await _tap(tester, find.text('View all'));
        expect(find.byType(TransferRow), findsNWidgets(6));
        await _tap(tester, find.text('Show fewer'));
        expect(find.byType(TransferRow), findsNWidgets(4));
      });

      testWidgets('no View all at 4 rows or fewer', (tester) async {
        await _openSplit(tester);
        expect(find.text('View all'), findsNothing);
      });

      testWidgets('settled: everyone is square', (tester) async {
        await _openSplit(
          tester,
          tabs: [
            _tab('solo', 100000, paidBy: 'ari', among: ['ari', 'ben']),
            _tab('back', 100000, paidBy: 'ben', among: ['ari', 'ben']),
          ],
        );
        expect(find.text('₹1,000.00 spent by you'), findsOneWidget);
        expect(find.text('All square 🎉'), findsOneWidget);
        expect(find.text('Everyone is square 🎉'), findsOneWidget);
        expect(find.text('See detailed breakdown'), findsOneWidget);
      });

      testWidgets('long names and big amounts fit a small phone', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(320, 640)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final long = FakeSquadService()
          ..names['cara'] = 'Carolina Fernandez-Montgomery the Third';
        await _openSplit(
          tester,
          squad: long,
          tabs: [
            _tab('t', 900000000, paidBy: 'ari', among: ['ari', 'cara']),
          ],
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(_row('cara', 'ari')), findsOneWidget);
      });
    });

    group('Spend by category', () {
      TabEntry spent(String id, String category, int minor) => TabEntry(
        id: id,
        description: id,
        category: category,
        date: DateTime(2026, 10, 27),
        createdBy: 'ari',
        split: TabSplit(
          amount: Money(minor, 'INR'),
          payers: [Payment('ari', minor)],
          participants: const ['ari', 'ben'],
          fxDate: '2026-10-27',
        ),
      );

      testWidgets('total, top 3 and Other, every number in text', (
        tester,
      ) async {
        await _openSplit(
          tester,
          tabs: [
            spent('a', 'food_dining', 400000),
            spent('b', 'local_transportation', 300000),
            spent('c', 'accommodation', 200000),
            spent('d', 'shopping_souvenirs', 60000),
            spent('e', 'activities_sightseeing', 40000),
          ],
        );
        expect(find.text('Spend by category'), findsOneWidget);
        expect(find.text('Total spend ₹10,000.00'), findsOneWidget);
        for (final (label, percent, money) in [
          ('Food & Dining', '40%', '₹4,000.00'),
          ('Other', '10%', '₹1,000.00'),
        ]) {
          expect(find.text(label), findsOneWidget);
          expect(find.text(percent), findsOneWidget);
          expect(find.text(money), findsOneWidget);
        }
        // Four segments in the bar, in a 2×2 legend.
        expect(find.byKey(const ValueKey('category-bar')), findsOneWidget);
        expect(find.byType(CategoryLegendEntry), findsNWidgets(4));
        final first = tester.getTopLeft(find.byType(CategoryLegendEntry).at(0));
        final second = tester.getTopLeft(
          find.byType(CategoryLegendEntry).at(1),
        );
        final third = tester.getTopLeft(find.byType(CategoryLegendEntry).at(2));
        expect(first.dy, second.dy);
        expect(third.dy, greaterThan(first.dy));
      });

      testWidgets('a tiny category still gets a visible slice', (tester) async {
        await _openSplit(
          tester,
          tabs: [
            spent('a', 'food_dining', 10000000),
            spent('b', 'shopping_souvenirs', 100),
          ],
        );
        final slice = find.byKey(const ValueKey('category-slice-1'));
        expect(tester.getSize(slice).width, greaterThanOrEqualTo(6));
        // The slices fill the bar's height, or there's nothing to see.
        final colour = find.descendant(
          of: slice,
          matching: find.byType(ColoredBox),
        );
        expect(tester.getSize(colour).height, 16);
      });

      testWidgets('not shown when nothing has been shared', (tester) async {
        await _openSplit(tester, tabs: const []);
        expect(find.text('Spend by category'), findsNothing);
      });

      testWidgets('personal tabs stay out of squad totals', (tester) async {
        await _openSplit(
          tester,
          tabs: [
            _dinner,
            _tab(
              'p',
              50000,
              paidBy: 'ari',
              among: ['ari'],
              status: TabStatus.personal,
            ),
          ],
        );
        expect(find.text('₹2,000.00 spent by you'), findsOneWidget);
        expect(find.text('Total spend ₹3,000.00'), findsOneWidget);
      });

      testWidgets('fits a small phone', (tester) async {
        tester.view
          ..physicalSize = const Size(320, 640)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await _openSplit(
          tester,
          tabs: [
            spent('a', 'food_dining', 990000000),
            spent('b', 'local_transportation', 300000000),
            spent('c', 'accommodation', 200000000),
            spent('d', 'shopping_souvenirs', 60000000),
            spent('e', 'activities_sightseeing', 40000000),
          ],
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(CategoryLegendEntry), findsNWidgets(4));
      });
    });

    group('See detailed breakdown', () {
      testWidgets('expands and folds in place', (tester) async {
        await _openSplit(tester);
        await _tap(tester, find.text('See detailed breakdown'));
        expect(find.text('Balances'), findsOneWidget);
        expect(find.text('All categories'), findsOneWidget);
        expect(find.text('Spend by day'), findsOneWidget);

        await _tap(tester, find.text('Hide breakdown'));
        expect(find.text('Balances'), findsNothing);
      });

      testWidgets('balances have pictures, pals included, you say You', (
        tester,
      ) async {
        await _openSplit(tester);
        await _tap(tester, find.text('See detailed breakdown'));
        for (final (id, name) in [
          ('ari', 'You'),
          ('ben', 'Ben Roy'),
          ('kiko', 'Kiko'),
        ]) {
          final row = find.byKey(ValueKey('balance-$id'));
          expect(
            find.descendant(of: row, matching: find.byType(PersonAvatar)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: row, matching: find.text(name)),
            findsOneWidget,
          );
        }
      });

      testWidgets('all categories are listed, even past the top 3', (
        tester,
      ) async {
        TabEntry spent(String id, String category) => TabEntry(
          id: id,
          description: id,
          category: category,
          date: DateTime(2026, 10, 27),
          createdBy: 'ari',
          split: TabSplit(
            amount: Money(10000, 'INR'),
            payers: const [Payment('ari', 10000)],
            participants: const ['ari', 'ben'],
            fxDate: '2026-10-27',
          ),
        );
        await _openSplit(
          tester,
          tabs: [
            spent('a', 'food_dining'),
            spent('b', 'local_transportation'),
            spent('c', 'accommodation'),
            spent('d', 'shopping_souvenirs'),
            spent('e', 'activities_sightseeing'),
          ],
        );
        await _tap(tester, find.text('See detailed breakdown'));
        final list = find.byKey(const ValueKey('all-categories'));
        await tester.ensureVisible(list);
        expect(
          find.descendant(
            of: list,
            matching: find.textContaining(RegExp('₹100.00')),
          ),
          findsNWidgets(5),
        );
      });

      group('bars by day', () {
        final twoDays = [
          TabEntry(
            id: 'x',
            description: 'x',
            category: 'food_dining',
            date: DateTime(2026, 10, 25),
            createdBy: 'ari',
            split: TabSplit(
              amount: Money(10000, 'INR'),
              payers: const [Payment('ari', 10000)],
              participants: const ['ari', 'ben'],
              fxDate: '2026-10-25',
            ),
          ),
          _dinner,
        ];

        testWidgets('tapping a bar says its day and amount', (tester) async {
          await _openSplit(tester, tabs: twoDays);
          await _tap(tester, find.text('See detailed breakdown'));
          // Starts on the latest day; the empty day between still has a bar.
          expect(find.text('Tue, 27 Oct 2026 · ₹3,000.00'), findsOneWidget);
          expect(find.byKey(const ValueKey('day-2026-10-26')), findsOneWidget);

          await _tap(tester, find.byKey(const ValueKey('day-2026-10-25')));
          expect(find.text('Sun, 25 Oct 2026 · ₹100.00'), findsOneWidget);
        });

        testWidgets('TalkBack reads each bar’s day and amount', (tester) async {
          final semantics = tester.ensureSemantics();
          await _openSplit(tester, tabs: twoDays);
          await _tap(tester, find.text('See detailed breakdown'));
          expect(
            find.bySemanticsLabel('Sun, 25 Oct 2026: ₹100.00'),
            findsOneWidget,
          );
          semantics.dispose();
        });

        testWidgets('a long trip scrolls, starting at the latest day', (
          tester,
        ) async {
          final long = [
            for (var d = 1; d <= 28; d++)
              TabEntry(
                id: 'd$d',
                description: 'd$d',
                category: 'food_dining',
                date: DateTime(2026, 10, d),
                createdBy: 'ari',
                split: TabSplit(
                  amount: Money(1000 * d, 'INR'),
                  payers: [Payment('ari', 1000 * d)],
                  participants: const ['ari', 'ben'],
                  fxDate: '2026-10-${d.toString().padLeft(2, '0')}',
                ),
              ),
          ];
          await _openSplit(tester, tabs: long);
          await _tap(tester, find.text('See detailed breakdown'));
          expect(find.byKey(const ValueKey('day-2026-10-28')), findsOneWidget);
          expect(find.byKey(const ValueKey('day-2026-10-01')), findsNothing);
          expect(tester.takeException(), isNull);
        });
      });
    });

    group('the "•••" menu', () {
      testWidgets('holds Export; no currency switch when they match', (
        tester,
      ) async {
        await _openSplit(tester);
        await _tap(tester, find.byTooltip('More options'));
        expect(find.text('Export'), findsOneWidget);
        expect(find.textContaining('Show in'), findsNothing);
      });

      testWidgets('is gone when it would be empty', (tester) async {
        await _openSplit(tester, exportEnabled: false);
        expect(find.byTooltip('More options'), findsNothing);
      });

      testWidgets('with no tabs there’s nothing to export', (tester) async {
        await _openSplit(tester, tabs: const []);
        expect(find.byTooltip('More options'), findsNothing);
      });

      testWidgets('without rates there’s no currency to switch to', (
        tester,
      ) async {
        await _openSplit(tester, currency: 'THB');
        await _tap(tester, find.byTooltip('More options'));
        expect(find.textContaining('Show in'), findsNothing);
      });
    });

    group('tabs waiting for approval', () {
      final waiting = [
        _tab(
          'w1',
          30000,
          paidBy: 'ben',
          among: ['ari', 'ben'],
          status: TabStatus.waiting,
        ),
        _tab(
          'w2',
          40000,
          paidBy: 'ben',
          among: ['ari', 'ben'],
          status: TabStatus.waiting,
        ),
      ];

      testWidgets('a note under the top card opens the tab list', (
        tester,
      ) async {
        await _openSplit(tester, tabs: [_dinner, ...waiting]);
        expect(find.text('₹1,500.00 spent by you'), findsOneWidget);
        await _tap(tester, find.text('2 tabs waiting, not counted'));
        expect(find.byType(TabsSection), findsOneWidget);
      });

      testWidgets('one tab reads in the singular', (tester) async {
        await _openSplit(tester, tabs: [_dinner, waiting.first]);
        expect(find.text('1 tab waiting, not counted'), findsOneWidget);
      });

      testWidgets('only waiting tabs: says so, not "No tabs yet"', (
        tester,
      ) async {
        await _openSplit(tester, tabs: waiting);
        expect(find.textContaining('No tabs yet'), findsNothing);
        expect(find.text('Who pays whom'), findsNothing);
        expect(find.textContaining('not counted'), findsNothing);
        await _tap(tester, find.text('2 tabs waiting for approval'));
        expect(find.byType(TabsSection), findsOneWidget);
      });
    });

    testWidgets('only personal tabs: counted for you, nothing to split', (
      tester,
    ) async {
      await _openSplit(
        tester,
        tabs: [
          _tab(
            'p',
            50000,
            paidBy: 'ari',
            among: ['ari'],
            status: TabStatus.personal,
          ),
        ],
      );
      expect(find.text('₹500.00 spent by you'), findsOneWidget);
      expect(find.textContaining('No tabs yet'), findsNothing);
      expect(find.text('Only your personal tabs so far.'), findsOneWidget);
      expect(find.text('Open adventure'), findsOneWidget);
    });

    testWidgets('rates missing for a tab: a note, not a false ₹0', (
      tester,
    ) async {
      await _openSplit(
        tester,
        tabs: [
          _tab(
            'eur',
            9000,
            paidBy: 'ari',
            among: ['ari', 'ben'],
            currency: 'EUR',
          ),
        ],
      );
      expect(find.textContaining('spent by you'), findsNothing);
      expect(
        find.text(
          'We can’t work out this split yet: exchange rates aren’t '
          'available.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('No tabs yet'), findsNothing);
      expect(find.text('Open adventure'), findsOneWidget);
    });

    testWidgets('with no active adventure it opens on Overall', (tester) async {
      await _openSplit(tester, adventure: _goa(end: DateTime(2026, 10, 27)));

      expect(find.text('Your share across adventures'), findsOneWidget);
      expect(find.text('₹1,500.00'), findsWidgets); // Ari's 50%
      await _tap(tester, find.byKey(const ValueKey('overall-bkk')));
      expect(find.text('You’re owed ₹500.00'), findsOneWidget);
    });
  });
}
