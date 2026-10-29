import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';

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

Future<void> _openSplit(
  WidgetTester tester, {
  String as = 'ari',
  Adventure? adventure,
  List<TabEntry>? tabs,
  String currency = 'INR',
  Map<String, String> rates = const {},
}) async {
  await pumpRoamio(
    tester,
    FakeAuthService(
      initial: SessionFacts(uid: as, hasAccount: true, ageStatus: 'adult'),
    ),
    adventures: FakeAdventureService([adventure ?? _goa()]),
    tabs: FakeTabService(tabs ?? [_dinner]),
    squad: FakeSquadService()
      ..names.addAll({'ari': 'Ari Chen', 'ben': 'Ben Roy'})
      ..palsByAdventure['bkk'] = [const Pal(id: 'kiko', nickname: 'Kiko')],
    fx: FakeFxRepository(rates),
    profileCurrency: currency,
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

      expect(find.text('You’re owed ₹500.00'), findsOneWidget);
      // Details only on request.
      expect(find.text('Who pays whom'), findsNothing);

      await _tap(tester, find.text('See the details'));
      expect(find.text('Kiko pays you'), findsOneWidget);
      expect(find.text('Kiko pays Ben Roy'), findsOneWidget);
      expect(find.text('₹500.00'), findsWidgets);
      expect(find.text('₹250.00'), findsWidgets);
      expect(find.text('+₹250.00'), findsOneWidget); // Ben's balance
      expect(find.text('-₹750.00'), findsOneWidget); // Kiko's balance
      expect(find.textContaining('Food & Dining'), findsOneWidget);
      expect(find.text('Tue, 27 Oct 2026'), findsOneWidget);
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

      // Tapping shows the trip-currency figure.
      await _tap(tester, find.text('You’re owed ฿208.34'));
      expect(find.text('In INR: You’re owed ₹500.00'), findsOneWidget);
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

    testWidgets('with no active adventure it opens on Overall', (tester) async {
      await _openSplit(tester, adventure: _goa(end: DateTime(2026, 10, 27)));

      expect(find.text('Your share across adventures'), findsOneWidget);
      expect(find.text('₹1,500.00'), findsWidgets); // Ari's 50%
      await _tap(tester, find.byKey(const ValueKey('overall-bkk')));
      expect(find.text('You’re owed ₹500.00'), findsOneWidget);
    });
  });
}
