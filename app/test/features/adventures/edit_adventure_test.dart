import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';

Adventure _bangkok({bool hasTabs = false}) => Adventure(
  id: 'bkk',
  name: 'Bangkok trip',
  description: 'Street food tour',
  countryCode: 'TH',
  city: 'Bangkok',
  startDate: DateTime(2026, 12),
  endDate: DateTime(2026, 12, 8),
  baseCurrency: 'THB',
  leaderUid: 'ari',
  coLeadUids: const ['cara'],
  memberUids: const ['ari', 'cara', 'bob'],
  hasTabs: hasTabs,
);

Future<FakeAdventureService> _openEdit(
  WidgetTester tester, {
  String as = 'ari',
  bool hasTabs = false,
}) async {
  final adventures = FakeAdventureService([_bangkok(hasTabs: hasTabs)]);
  await pumpRoamio(
    tester,
    FakeAuthService(
      initial: SessionFacts(uid: as, hasAccount: true, ageStatus: 'adult'),
    ),
    adventures: adventures,
  );
  await tester.tap(find.text('Bangkok trip'));
  await tester.pumpAndSettle();
  return adventures;
}

Future<void> _tapEdit(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Edit adventure'));
  await tester.pumpAndSettle();
}

void main() {
  group('edit adventure (UC-10)', () {
    testWidgets('only leads see Edit', (tester) async {
      await _openEdit(tester, as: 'bob');
      expect(find.byTooltip('Edit adventure'), findsNothing);
    });

    testWidgets('co-leads can edit too', (tester) async {
      await _openEdit(tester, as: 'cara');
      expect(find.byTooltip('Edit adventure'), findsOneWidget);
    });

    testWidgets('a lead changes the name and description', (tester) async {
      final adventures = await _openEdit(tester);
      await _tapEdit(tester);

      expect(find.text('Edit adventure'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Adventure name'),
        '  Bangkok & Krabi  ',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Description (optional)'),
        'Food and beaches',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final (id, edit) = adventures.edits.single;
      expect(id, 'bkk');
      // Only what changed is sent, so the other fields can't overwrite
      // a co-lead's change to them (item 6).
      expect(edit.name, '  Bangkok & Krabi  ');
      expect(edit.description, 'Food and beaches');
      expect(edit.city, isNull);
      expect(edit.startDate, isNull);
      expect(edit.endDate, isNull);
      expect(edit.baseCurrency, isNull);
      // Back on the adventure, showing the new name.
      expect(find.text('Bangkok & Krabi'), findsWidgets);
    });

    testWidgets('an empty name is refused', (tester) async {
      final adventures = await _openEdit(tester);
      await _tapEdit(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Adventure name'),
        '   ',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Give it a name.'), findsOneWidget);
      expect(adventures.edits, isEmpty);
    });

    testWidgets('the currency is locked once there are tabs', (tester) async {
      final adventures = await _openEdit(tester, hasTabs: true);
      await _tapEdit(tester);

      expect(find.textContaining('Locked'), findsOneWidget);
      final field = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(field.onChanged, isNull);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(adventures.edits.single.$2.baseCurrency, isNull);
    });

    testWidgets('the country is shown but not editable', (tester) async {
      await _openEdit(tester);
      await _tapEdit(tester);
      expect(find.textContaining('Thailand'), findsOneWidget);
      expect(find.textContaining('can’t be changed'), findsOneWidget);
    });
  });
}
