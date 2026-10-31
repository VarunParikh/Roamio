import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/connectivity/connectivity_monitor.dart';
import 'package:roamio/core/router/app_router.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/sync/sync_controller.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_fx_repository.dart';
import '../../support/fake_sync.dart';
import '../../support/fake_tab_service.dart';

/// A baht trip for someone who thinks in rupees. "Today" is 29 Oct 2026.
final Adventure _thailand = Adventure(
  id: 'bkk',
  name: 'Thailand',
  countryCode: 'TH',
  startDate: DateTime(2026, 10, 20),
  endDate: DateTime(2026, 11, 2),
  baseCurrency: 'THB',
  leaderUid: 'ari',
  memberUids: const ['ari', 'ben'],
);

final TabEntry _boat = TabEntry(
  id: 't',
  description: 'Boat',
  category: 'food_dining',
  date: DateTime(2026, 10, 27),
  createdBy: 'ari',
  split: TabSplit(
    amount: Money(100000, 'THB'),
    payers: const [Payment('ari', 100000)],
    participants: const ['ari', 'ben'],
    fxDate: '2026-10-27',
  ),
);

const _usd = {'INR': '84', 'THB': '33.6'};
const _button = 'Update rates';

Future<FakeFxRepository> _pump(
  WidgetTester tester,
  String location, {
  Map<String, String> rates = const {},
  Map<String, String> latest = _usd,
  String currency = 'INR',
  String tripCurrency = 'THB',
  FakeConnectivity? connectivity,
}) async {
  final fx = FakeFxRepository(rates, latest);
  await pumpRoamio(
    tester,
    FakeAuthService(
      initial: const SessionFacts(
        uid: 'ari',
        hasAccount: true,
        ageStatus: 'adult',
      ),
    ),
    adventures: FakeAdventureService([
      Adventure(
        id: 'bkk',
        name: 'Thailand',
        countryCode: 'TH',
        startDate: _thailand.startDate,
        endDate: _thailand.endDate,
        baseCurrency: tripCurrency,
        leaderUid: 'ari',
        memberUids: const ['ari', 'ben'],
      ),
    ]),
    tabs: FakeTabService([_boat]),
    fx: fx,
    profileCurrency: currency,
    connectivity: connectivity,
  );
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
  await tester.pumpAndSettle();
  return fx;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('Update rates (spec §9.1)', () {
    testWidgets('on Split: fetches, and the figures convert straight away', (
      tester,
    ) async {
      final fx = await _pump(tester, Routes.splitFor('bkk'));
      expect(find.textContaining('exchange rates aren’t'), findsWidgets);

      await _tap(tester, find.text(_button));

      expect(fx.refreshes, 1);
      expect(find.text('₹1,250.00 spent by you'), findsOneWidget);
      expect(find.textContaining('Rates updated'), findsOneWidget);
    });

    testWidgets('on the adventure’s tab list', (tester) async {
      final fx = await _pump(tester, '/adventures/bkk');
      await tester.scrollUntilVisible(
        find.text(_button),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await _tap(tester, find.text(_button));
      expect(fx.refreshes, 1);
    });

    testWidgets('not shown when nothing needs converting', (tester) async {
      await _pump(tester, Routes.splitFor('bkk'), currency: 'THB');
      expect(find.text(_button), findsNothing);
    });

    testWidgets('the provider being down says so and changes nothing', (
      tester,
    ) async {
      final fx = await _pump(tester, Routes.splitFor('bkk'), latest: const {});
      await _tap(tester, find.text(_button));
      expect(fx.refreshes, 1);
      expect(
        find.text('No exchange rates available yet. Try again later.'),
        findsOneWidget,
      );
    });

    testWidgets('a failure explains itself', (tester) async {
      final fx = await _pump(tester, Routes.splitFor('bkk'));
      fx.failRefresh = true;
      await _tap(tester, find.text(_button));
      expect(
        find.text('Couldn’t get the latest rates. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('offline it’s switched off', (tester) async {
      final fx = await _pump(
        tester,
        Routes.splitFor('bkk'),
        connectivity: FakeConnectivity(online: false),
      );
      await _tap(tester, find.text(_button));
      expect(fx.refreshes, 0);
    });
  });

  group('the conversion on Add tab', () {
    Future<void> amount(WidgetTester tester, String text) async {
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), text);
      await tester.pumpAndSettle();
    }

    testWidgets('shows in your currency as you type', (tester) async {
      await _pump(tester, '/adventures/bkk/tabs/new', rates: _usd);
      expect(find.textContaining('≈'), findsNothing);
      await amount(tester, '1000');
      expect(find.text('≈ ₹2,500.00 in your currency'), findsOneWidget);
      await amount(tester, '100');
      expect(find.text('≈ ₹250.00 in your currency'), findsOneWidget);
    });

    testWidgets('nothing when the tab is already in your currency', (
      tester,
    ) async {
      await _pump(
        tester,
        '/adventures/bkk/tabs/new',
        rates: _usd,
        tripCurrency: 'INR',
      );
      await amount(tester, '1000');
      expect(find.textContaining('≈'), findsNothing);
      expect(find.text(_button), findsNothing);
    });

    testWidgets('without rates it says so, and can fetch them', (tester) async {
      await _pump(tester, '/adventures/bkk/tabs/new');
      await amount(tester, '1000');
      expect(
        find.text('Can’t convert yet: no exchange rates.'),
        findsOneWidget,
      );

      await _tap(tester, find.text(_button));
      expect(find.text('≈ ₹2,500.00 in your currency'), findsOneWidget);
    });
  });

  group('Synced', () {
    testWidgets('hides by itself after 3 seconds, on any screen', (
      tester,
    ) async {
      final connectivity = FakeConnectivity(online: false);
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        connectivity: connectivity,
      );
      connectivity.set(online: true);
      await tester.pump();
      await tester.pump();
      expect(find.text('Synced ✓'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2900));
      expect(find.text('Synced ✓'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.text('Synced ✓'), findsNothing);
    });

    testWidgets('hides even if no banner was on screen when it synced', (
      tester,
    ) async {
      final connectivity = FakeConnectivity(online: false);
      final container = ProviderContainer(
        overrides: [
          connectivityMonitorProvider.overrideWithValue(connectivity),
          networkSwitchProvider.overrideWithValue(FakeNetworkSwitch()),
          photoFlushProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(syncControllerProvider.notifier);
      await notifier.ready;
      connectivity.set(online: true);
      await tester.pump();
      await tester.pump();
      expect(container.read(syncControllerProvider).phase, SyncPhase.synced);

      await tester.pump(const Duration(seconds: 4));
      expect(container.read(syncControllerProvider).phase, SyncPhase.online);
    });
  });
}
