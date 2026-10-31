import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/splits/data/fx_repository.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/squad/data/squad_service.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_squad_service.dart';
import '../../support/fake_tab_service.dart';

/// Happening now (today is 29 Oct 2026). Ari leads, Bob is a member and
/// Kiko is a pal.
Adventure _bangkok({DateTime? end}) => Adventure(
  id: 'bkk',
  name: 'Bangkok trip',
  countryCode: 'TH',
  startDate: DateTime(2026, 10, 10),
  endDate: end ?? DateTime(2026, 11, 2),
  baseCurrency: 'THB',
  leaderUid: 'ari',
  memberUids: const ['ari', 'bob'],
);

Future<FakeTabService> _openAdventure(
  WidgetTester tester, {
  Adventure? adventure,
  FxRepository? fx,
}) async {
  final tabs = FakeTabService();
  await pumpRoamio(
    tester,
    FakeAuthService(initial: readyFacts),
    adventures: FakeAdventureService([adventure ?? _bangkok()]),
    squad: FakeSquadService()
      ..names.addAll({'ari': 'Ari Chen', 'bob': 'Bob Lee'})
      ..palsByAdventure['bkk'] = [const Pal(id: 'kiko', nickname: 'Kiko')],
    tabs: tabs,
    fx: fx,
  );
  // A finished trip sits in the collapsed Past list.
  final past = find.textContaining('Past adventures');
  if (past.evaluate().isNotEmpty) {
    await tester.tap(past);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Bangkok trip'));
  await tester.pumpAndSettle();
  return tabs;
}

Future<void> _tick(WidgetTester tester, String name) async {
  final box = find.widgetWithText(CheckboxListTile, name);
  await tester.ensureVisible(box);
  await tester.pumpAndSettle();
  await tester.tap(box);
  await tester.pumpAndSettle();
}

Future<void> _openAddTab(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Add tab'), 200);
  await _tapVisible(tester, find.text('Add tab'));
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save tab'));
  await tester.tap(find.text('Save tab'));
  await tester.pumpAndSettle();
}

void main() {
  group('Add tab (UC-21, basic)', () {
    testWidgets('saves an equal split paid by you and lists it', (
      tester,
    ) async {
      final tabs = await _openAdventure(tester);
      await _openAddTab(tester);

      // Defaults: base currency, today, paid by you, everyone ticked.
      expect(find.text('THB'), findsOneWidget);
      expect(find.text('Thu, 29 Oct 2026'), findsOneWidget);
      expect(find.text('You paid it all'), findsOneWidget);
      for (final name in ['Ari Chen (you)', 'Bob Lee', 'Kiko']) {
        final box = tester.widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, name),
        );
        expect(box.value, isTrue, reason: name);
      }

      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '900');
      await tester.pumpAndSettle();
      expect(find.text('฿300.00 each'), findsOneWidget);
      await _tapVisible(tester, find.textContaining('Food & Dining'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Description (optional)'),
        'Dinner at Jay Fai',
      );
      await _save(tester);

      final (aid, tab) = tabs.added.single;
      expect(aid, 'bkk');
      expect(tab.amountMinor, 90000);
      expect(tab.currency, 'THB');
      expect(tab.category, 'food_dining');
      expect(tab.payers.map((p) => (p.payer, p.amountMinor)), [('ari', 90000)]);
      expect(tab.participants, ['ari', 'bob', 'kiko']);
      expect(tab.date, DateTime(2026, 10, 29));

      // Back on the adventure, the tab shows with your share.
      await tester.scrollUntilVisible(find.text('Dinner at Jay Fai'), 200);
      expect(find.text('฿900.00'), findsOneWidget);
      expect(find.text('Your share ฿300.00'), findsOneWidget);
      expect(find.text('💵'), findsOneWidget);
    });

    testWidgets('keeps the day of the rates it used (follow-up C4)', (
      tester,
    ) async {
      // It's the 29th, but the 29th's rates haven't arrived yet.
      final tabs = await _openAdventure(
        tester,
        fx: _RatesFrom('2026-10-28', const {'THB': '35'}),
      );
      await _openAddTab(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '900');
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.textContaining('Food & Dining'));
      await _save(tester);

      final (_, tab) = tabs.added.single;
      expect(tab.date, DateTime(2026, 10, 29));
      expect(tab.fxDate, '2026-10-28');

      // The tab says which day's rates convert it.
      await tester.scrollUntilVisible(find.text('Food & Dining'), 200);
      await _tapVisible(tester, find.text('Food & Dining'));
      expect(
        find.text('Converted at exchange rates from Wed, 28 Oct 2026'),
        findsOneWidget,
      );
    });

    testWidgets('unticking someone changes the split', (tester) async {
      final tabs = await _openAdventure(tester);
      await _openAddTab(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '900');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await _tick(tester, 'Kiko');
      expect(find.text('฿450.00 each'), findsOneWidget);
      await _tapVisible(tester, find.textContaining('Food & Dining'));
      await _save(tester);

      expect(tabs.added.single.$2.participants, ['ari', 'bob']);
    });

    testWidgets('explains what is missing and saves nothing', (tester) async {
      final tabs = await _openAdventure(tester);
      await _openAddTab(tester);

      for (final name in ['Ari Chen (you)', 'Bob Lee', 'Kiko']) {
        await _tick(tester, name);
      }
      await _save(tester);

      expect(find.text('Enter an amount above zero.'), findsOneWidget);
      expect(find.text('Pick a category.'), findsOneWidget);
      expect(find.text('Tick at least one person.'), findsOneWidget);
      expect(tabs.added, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextField, 'Amount'),
        '20,000,000',
      );
      await _save(tester);
      expect(find.text('That’s more than 10,000,000.'), findsOneWidget);
    });

    testWidgets('tabs close 7 days after the trip ends (UC-11)', (
      tester,
    ) async {
      await _openAdventure(
        tester,
        adventure: _bangkok(end: DateTime(2026, 10, 21)),
      );
      await tester.scrollUntilVisible(find.text('Add tab'), 200);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Add tab'),
      );
      expect(button.onPressed, isNull);
      expect(find.textContaining('closed'), findsOneWidget);
    });

    testWidgets('an empty list says how to start', (tester) async {
      await _openAdventure(tester);
      await tester.scrollUntilVisible(find.text('Add tab'), 200);
      expect(find.text('No tabs yet. Add the first one.'), findsOneWidget);
    });
  });
}

/// Always answers with one stored day's rates, whatever day is asked for.
class _RatesFrom implements FxRepository {
  new(this.day, this.rates);

  final String day;
  final Map<String, String> rates;

  @override
  Future<FxRates?> ratesFor(String date) async =>
      FxRates(date: day, usdRates: rates);

  @override
  Future<String?> refreshLatest() async => null;

  @override
  Stream<String?> watchLatestDay() => Stream.value(day);
}
