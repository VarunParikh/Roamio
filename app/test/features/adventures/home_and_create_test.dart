import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/ui/primary_button.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_sync.dart';
import 'adventure_test.dart' show trip;

void main() {
  // pumpRoamio fixes "today" at 29 Oct 2026.
  DateTime d(int m, int day) => DateTime(2026, m, day);

  group('Home (UC-5, UC-6)', () {
    testWidgets('empty: greeting and one pulsing Create a new adventure', (
      tester,
    ) async {
      await pumpRoamio(tester, FakeAuthService(initial: readyFacts));

      expect(find.text('Hey Ari 👋'), findsOneWidget);
      expect(find.text('No adventures yet'), findsOneWidget);
      expect(find.byType(PrimaryButton), findsOneWidget);
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.pulse, isTrue);
      expect(button.label, 'Create a new adventure');
    });

    testWidgets('never says no adventures before it knows', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService()..neverAnswer = true,
        settle: false,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('No adventures yet'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('offline with nothing known: says so, and can still create', (
      tester,
    ) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService()..neverAnswer = true,
        connectivity: FakeConnectivity(online: false),
        settle: false,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('No adventures yet'), findsNothing);
      expect(find.textContaining('when you’re back online'), findsOneWidget);
      expect(find.text('Create a new adventure'), findsOneWidget);
    });

    testWidgets('hero, coming up and past sections', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([
          trip('bkk', d(10, 27), d(11, 2)),
          trip('goa', d(12, 20), d(12, 27)),
          trip('old', d(6, 1), d(6, 5)),
        ]),
      );

      expect(find.text('Trip bkk'), findsOneWidget);
      expect(find.text('CURRENT ADVENTURE'), findsOneWidget);
      expect(find.text('Upcoming adventures'), findsOneWidget);
      expect(find.text('Trip goa'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Past adventures (1)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Trip old'), findsNothing);

      await tester.tap(find.text('Past adventures (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Trip old'), findsOneWidget);
    });

    testWidgets('tapping the hero opens the adventure', (tester) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([trip('bkk', d(10, 27), d(11, 2))]),
      );
      await tester.tap(find.text('Trip bkk'));
      await tester.pumpAndSettle();
      expect(
        find.text('Trip currency: THB · ', findRichText: true),
        findsNothing,
      );
      expect(find.textContaining('Trip currency: THB'), findsOneWidget);
    });
  });

  group('Create adventure (UC-8)', () {
    Future<FakeAdventureService> start(WidgetTester tester) async {
      final adventures = FakeAdventureService();
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: adventures,
      );
      await tester.tap(find.text('Create a new adventure'));
      await tester.pumpAndSettle();
      return adventures;
    }

    Future<void> chooseThailand(WidgetTester tester) async {
      await tester.tap(find.text('Choose a country'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'thai');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thailand'));
      await tester.pumpAndSettle();
    }

    testWidgets('each step checks its own fields', (tester) async {
      await start(tester);
      expect(find.text('Step 1 of 3'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a country.'), findsOneWidget);

      await chooseThailand(tester);
      expect(find.text('🇹🇭  Thailand'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 3'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Give it a name.'), findsOneWidget);
    });

    testWidgets(
      'creates the adventure with the country currency, then opens it',
      (tester) async {
        final adventures = await start(tester);
        await chooseThailand(tester);
        await tester.enterText(
          find.widgetWithText(TextField, 'City or region (optional)'),
          'Bangkok',
        );
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Adventure name'),
          'College group’s Bangkok adventure',
        );
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('THB'), findsOneWidget);

        await tester.tap(find.text('Create adventure'));
        await tester.pumpAndSettle();
        expect(find.text('Choose the dates.'), findsOneWidget);
        expect(adventures.created, isEmpty);

        await tester.tap(find.text('Choose dates'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(0), '12/01/2026');
        await tester.enterText(find.byType(TextField).at(1), '12/08/2026');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.text('1 – 8 Dec 2026'), findsOneWidget);

        await tester.tap(find.text('Create adventure'));
        await tester.pumpAndSettle();

        final draft = adventures.created.single;
        expect(draft.countryCode, 'TH');
        expect(draft.city, 'Bangkok');
        expect(draft.baseCurrency, 'THB');
        expect(draft.startDate, DateTime(2026, 12));
        expect(draft.endDate, DateTime(2026, 12, 8));
        expect(find.textContaining('Trip currency: THB'), findsOneWidget);
      },
    );

    testWidgets('back goes to the previous step, not out of the flow', (
      tester,
    ) async {
      await start(tester);
      await chooseThailand(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.text('🇹🇭  Thailand'), findsOneWidget);
    });

    testWidgets('explains a failed save', (tester) async {
      final adventures = await start(tester);
      adventures.failNext = true;
      await chooseThailand(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Adventure name'),
        'BKK',
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose dates'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '12/01/2026');
      await tester.enterText(find.byType(TextField).at(1), '12/02/2026');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create adventure'));
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn’t create it. Check your connection.'),
        findsOneWidget,
      );
    });
  });
}
