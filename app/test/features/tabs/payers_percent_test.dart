import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/squad/data/squad_service.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_squad_service.dart';
import '../../support/fake_tab_service.dart';

/// Ari leads, Bob is a member, Kiko is a pal.
final _bangkok = Adventure(
  id: 'bkk',
  name: 'Bangkok trip',
  countryCode: 'TH',
  startDate: DateTime(2026, 10, 10),
  endDate: DateTime(2026, 11, 2),
  baseCurrency: 'THB',
  leaderUid: 'ari',
  memberUids: const ['ari', 'bob'],
);

class _H {
  final tabs = FakeTabService();
  final squad = FakeSquadService()
    ..names.addAll({'ari': 'Ari Chen', 'bob': 'Bob Lee'})
    ..palsByAdventure['bkk'] = [const Pal(id: 'kiko', nickname: 'Kiko')];
}

Future<_H> _open(WidgetTester tester, {String as = 'ari'}) async {
  final h = _H();
  await pumpRoamio(
    tester,
    FakeAuthService(
      initial: SessionFacts(uid: as, hasAccount: true, ageStatus: 'adult'),
    ),
    adventures: FakeAdventureService([_bangkok]),
    squad: h.squad,
    tabs: h.tabs,
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

Future<void> _type(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

bool _canSave(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed != null;

void main() {
  group('split payment (UC-21)', () {
    testWidgets('several members pay; amounts must add up', (tester) async {
      final h = await _open(tester);
      await _tap(tester, find.text('Split payment'));

      // Members only: pals never pay.
      expect(find.byKey(const ValueKey('pay-ari')), findsOneWidget);
      expect(find.byKey(const ValueKey('pay-bob')), findsOneWidget);
      expect(find.byKey(const ValueKey('pay-kiko')), findsNothing);
      expect(find.text('฿900.00 of ฿900.00 assigned'), findsOneWidget);

      await _type(tester, 'pay-ari', '600');
      expect(find.text('฿600.00 of ฿900.00 assigned'), findsOneWidget);
      expect(_canSave(tester), isFalse);

      await _type(tester, 'pay-bob', '300');
      expect(_canSave(tester), isTrue);
      await _tap(tester, find.text('Save tab'));

      final payers = h.tabs.added.single.$2.payers;
      expect(payers.map((p) => (p.payer, p.amountMinor)), [
        ('ari', 60000),
        ('bob', 30000),
      ]);
    });

    testWidgets('Just me goes back to one payer', (tester) async {
      final h = await _open(tester);
      await _tap(tester, find.text('Split payment'));
      await _type(tester, 'pay-ari', '100');
      await _tap(tester, find.text('Just me'));

      expect(find.text('You paid it all'), findsOneWidget);
      await _tap(tester, find.text('Save tab'));
      expect(h.tabs.added.single.$2.payers.single.amountMinor, 90000);
    });
  });

  group('custom % (UC-21, UC-22)', () {
    testWidgets('starts at an equal 100% and must stay at 100%', (
      tester,
    ) async {
      final h = await _open(tester);
      await _tap(tester, find.text('Custom %'));

      expect(find.text('100% of 100% assigned'), findsOneWidget);
      await _type(tester, 'pct-ari', '10');
      expect(find.text('76.66% of 100% assigned'), findsOneWidget);
      expect(_canSave(tester), isFalse);

      await _type(tester, 'pct-ari', '50');
      await _type(tester, 'pct-bob', '25');
      await _type(tester, 'pct-kiko', '25');
      expect(_canSave(tester), isTrue);
      await _tap(tester, find.text('Save tab'));

      expect(h.tabs.added.single.$2.percentBp, {
        'ari': 5000,
        'bob': 2500,
        'kiko': 2500,
      });
    });

    testWidgets('unticking someone resets to Equal and says so', (
      tester,
    ) async {
      final h = await _open(tester);
      await _tap(tester, find.text('Custom %'));
      await _tap(tester, find.widgetWithText(CheckboxListTile, 'Kiko'));

      expect(
        find.text('Split reset to equal because the people changed.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('pct-ari')), findsNothing);
      await _tap(tester, find.text('Save tab'));
      expect(h.tabs.added.single.$2.percentBp, isNull);
      expect(h.tabs.added.single.$2.participants, ['ari', 'bob']);
    });
  });

  group('+ Add pal while adding a tab (UC-21, leads only)', () {
    testWidgets('a lead adds a pal who joins the squad and shares', (
      tester,
    ) async {
      final h = await _open(tester);
      await _tap(tester, find.text('Add pal'));
      await tester.enterText(find.widgetWithText(TextField, 'Nickname'), 'Lu');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(h.squad.calls, ['addPal:bkk/Lu']);
      final lu = find.widgetWithText(CheckboxListTile, 'Lu');
      expect(tester.widget<CheckboxListTile>(lu).value, isTrue);
      await _tap(tester, find.text('Save tab'));
      expect(h.tabs.added.single.$2.participants, [
        'ari',
        'bob',
        'kiko',
        'pal1',
      ]);
    });

    testWidgets('members who aren’t leads don’t see it', (tester) async {
      await _open(tester, as: 'bob');
      expect(find.text('Add pal'), findsNothing);
    });
  });
}
