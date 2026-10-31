import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/splits/data/settlement_service.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/squad/ui/person.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_settlement_service.dart';
import '../../support/fake_squad_service.dart';
import '../../support/fake_tab_service.dart';

/// Ari leads, Ben is a member, Kiko is a pal. Spec §6 worked example.
final _goa = Adventure(
  id: 'bkk',
  name: 'Goa trip',
  countryCode: 'IN',
  startDate: DateTime(2026, 10, 20),
  endDate: DateTime(2026, 11, 2),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari', 'ben'],
);

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

Future<FakeSettlementService> _openDetails(
  WidgetTester tester, {
  String as = 'ari',
  List<SettlementEntry> already = const [],
}) async {
  final settlements = FakeSettlementService(already);
  await pumpRoamio(
    tester,
    FakeAuthService(
      initial: SessionFacts(uid: as, hasAccount: true, ageStatus: 'adult'),
    ),
    adventures: FakeAdventureService([_goa]),
    tabs: FakeTabService([_dinner]),
    squad: FakeSquadService()
      ..names.addAll({'ari': 'Ari Chen', 'ben': 'Ben Roy'})
      ..palsByAdventure['bkk'] = [const Pal(id: 'kiko', nickname: 'Kiko')],
    settlements: settlements,
  );
  await tester.tap(find.text('Split'));
  await tester.pumpAndSettle();
  return settlements;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _row(String from, String to) =>
    find.byKey(ValueKey('transfer-$from-$to'));

Finder _arrowOn(String from, String to) => find.descendant(
  of: _row(from, to),
  matching: find.byIcon(Icons.chevron_right),
);

Future<void> _breakdown(WidgetTester tester) =>
    _tap(tester, find.text('See detailed breakdown'));

void main() {
  group('Mark as settled (spec UC-26a)', () {
    testWidgets('records a suggested transfer in full', (tester) async {
      final s = await _openDetails(tester);

      await _tap(tester, _row('kiko', 'ari'));
      expect(find.textContaining('No money moves in Roamio'), findsOneWidget);
      // Both people, with their pictures (spec UC-28a).
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(PersonAvatar),
        ),
        findsNWidgets(2),
      );
      final amount = tester.widget<TextField>(find.byType(TextField).last);
      expect(amount.controller!.text, '500.00');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Mark as settled'));
      await tester.pumpAndSettle();

      final r = s.recorded.single;
      expect(
        (r.from, r.to, r.amountMinor, r.currency, r.date),
        ('kiko', 'ari', 50000, 'INR', '2026-10-29'),
      );
      expect(find.text('All square 🎉'), findsOneWidget);
      expect(_row('kiko', 'ari'), findsNothing);
      expect(_row('kiko', 'ben'), findsOneWidget);
      await _breakdown(tester);
      expect(find.text('Kiko paid you'), findsOneWidget);
    });

    testWidgets('a part payment can be recorded, but not more', (tester) async {
      final s = await _openDetails(tester);
      await _tap(tester, _row('kiko', 'ari'));

      await tester.enterText(find.byType(TextField).last, '600');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Mark as settled'));
      await tester.pumpAndSettle();
      expect(find.text('Up to ₹500.00.'), findsOneWidget);
      expect(s.recorded, isEmpty);

      await tester.enterText(find.byType(TextField).last, '200');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Mark as settled'));
      await tester.pumpAndSettle();
      expect(s.recorded.single.amountMinor, 20000);
      expect(find.text('You’re owed ₹300.00'), findsOneWidget);
    });

    testWidgets('only people in the payment, or a lead for pals, record it', (
      tester,
    ) async {
      await _openDetails(tester, as: 'ben');
      // Ben is in "Kiko pays Ben" but not in "Kiko pays Ari", and isn't a lead.
      expect(_arrowOn('kiko', 'ben'), findsOneWidget);
      expect(_arrowOn('kiko', 'ari'), findsNothing);
    });

    testWidgets('a recorded payment can be undone', (tester) async {
      final s = await _openDetails(
        tester,
        already: const [
          SettlementEntry(
            id: 's9',
            from: 'kiko',
            to: 'ari',
            amountMinor: 50000,
            currency: 'INR',
            date: '2026-10-28',
            recordedBy: 'ari',
          ),
        ],
      );
      expect(find.text('All square 🎉'), findsOneWidget);
      await _breakdown(tester);
      expect(find.text('Kiko paid you'), findsOneWidget);

      await _tap(tester, find.byTooltip('Undo'));
      expect(find.text('Undo this payment?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Undo'));
      await tester.pumpAndSettle();

      expect(s.undone, ['s9']);
      expect(find.text('You’re owed ₹500.00'), findsOneWidget);
    });
  });
}
