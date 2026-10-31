import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/images/photo_pipeline.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_photo_pipeline.dart';
import '../../support/fake_receipt_scanner.dart';
import '../../support/fake_tab_service.dart';

final _goa = Adventure(
  id: 'bkk',
  name: 'Goa trip',
  countryCode: 'IN',
  startDate: DateTime(2026, 10, 20),
  endDate: DateTime(2026, 11, 2),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari'],
);

const _bill = '''
SPICE ROUTE RESTAURANT
Date: 27/10/2026
Paneer Tikka   320.00
Grand Total  ₹ 588.00
''';

class _H {
  final tabs = FakeTabService();
  final photos = FakePhotoPipeline();
  final scanner = FakeReceiptScanner(_bill);
}

Future<_H> _openAddTab(WidgetTester tester, {bool ocr = true}) async {
  final h = _H();
  await pumpRoamio(
    tester,
    FakeAuthService(initial: readyFacts),
    adventures: FakeAdventureService([_goa]),
    tabs: h.tabs,
    photos: h.photos,
    scanner: h.scanner,
    ocrEnabled: ocr,
  );
  await tester.tap(find.text('Goa trip').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add tab'));
  await tester.pumpAndSettle();
  return h;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String _field(WidgetTester tester, String label) => tester
    .widget<TextField>(find.widgetWithText(TextField, label))
    .controller!
    .text;

void main() {
  group('Scan bill (UC-21, Task 26)', () {
    testWidgets('fills in amount, date and name, and keeps the bill photo', (
      tester,
    ) async {
      final h = await _openAddTab(tester);

      await _tap(tester, find.text('Scan bill'));
      expect(h.photos.billScans, 1); // the document scanner
      expect(h.scanner.read, ['/photos/1.jpg']);
      expect(_field(tester, 'Amount'), '588.00');
      expect(
        _field(tester, 'Description (optional)'),
        'Spice Route Restaurant',
      );
      expect(find.text('Tue, 27 Oct 2026'), findsOneWidget);
      expect(
        find.text('Check the amount, date and name we read.'),
        findsOneWidget,
      );
      expect(find.byTooltip('Remove photo'), findsOneWidget);

      await _tap(tester, find.textContaining('Food & Dining'));
      await _tap(tester, find.text('Save tab'));
      final tab = h.tabs.added.single.$2;
      expect(tab.amountMinor, 58800);
      expect(tab.date, DateTime(2026, 10, 27));
      // The bill is kept at the larger bill size, readable later.
      expect(h.photos.kinds, [PhotoKind.bill]);
    });

    testWidgets('a description already typed is kept', (tester) async {
      await _openAddTab(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Description (optional)'),
        'Team dinner',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Scan bill'));
      expect(_field(tester, 'Description (optional)'), 'Team dinner');
      expect(_field(tester, 'Amount'), '588.00');
    });

    testWidgets('an unreadable bill says so and changes nothing', (
      tester,
    ) async {
      final h = await _openAddTab(tester);
      h.scanner.text = '#### ~~~';
      await _tap(tester, find.text('Scan bill'));

      expect(
        find.text('Couldn’t read that bill. Please fill it in.'),
        findsOneWidget,
      );
      expect(_field(tester, 'Amount'), '');
    });

    testWidgets('with no total found it asks for the amount', (tester) async {
      final h = await _openAddTab(tester);
      h.scanner.text = 'SPICE ROUTE\nDate: 27/10/2026\nPaneer Tikka  320.00';
      await _tap(tester, find.text('Scan bill'));

      expect(
        find.text('We couldn’t find the total. Please add the amount.'),
        findsOneWidget,
      );
      expect(_field(tester, 'Amount'), '');
      expect(_field(tester, 'Description (optional)'), 'Spice Route');
    });

    testWidgets('if text reading fails it says so', (tester) async {
      final h = await _openAddTab(tester);
      h.scanner.fails = true;
      await _tap(tester, find.text('Scan bill'));
      expect(
        find.text('Couldn’t read that bill. Please fill it in.'),
        findsOneWidget,
      );
    });

    testWidgets('cancelling the camera does nothing', (tester) async {
      final h = await _openAddTab(tester);
      h.photos.cancelNext = true;
      await _tap(tester, find.text('Scan bill'));
      expect(h.scanner.read, isEmpty);
    });

    testWidgets('hidden when ocr_enabled is off (spec §11)', (tester) async {
      await _openAddTab(tester, ocr: false);
      expect(find.text('Scan bill'), findsNothing);
    });
  });
}
