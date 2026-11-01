import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/splits/ui/settle_sheet.dart';

const _navButtons = 48.0;
const _height = 800.0;

Future<void> _open(
  WidgetTester tester, {
  double keyboard = 0,
  double height = _height,
}) async {
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = Size(360 * 3, height * 3)
    ..padding = const FakeViewPadding(bottom: _navButtons * 3)
    ..viewPadding = const FakeViewPadding(bottom: _navButtons * 3)
    ..viewInsets = FakeViewPadding(bottom: keyboard * 3);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showSettleSheet(
                context,
                title: 'You paid Amit',
                suggestedMinor: 50000,
                currency: 'THB',
                people: const Text('You → Amit'),
                viewerCurrency: 'INR',
                currencies: const ['THB', 'INR'],
                rates: FxRates(
                  date: '2026-11-01',
                  usdRates: const {'INR': '84', 'THB': '35'},
                ),
                symbolFor: (_) => null,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('the settle sheet on a phone with navigation buttons', () {
    testWidgets('its button clears them', (tester) async {
      await _open(tester);
      final button = tester.getRect(find.byType(PrimaryButton));
      expect(button.bottom, lessThanOrEqualTo(_height - _navButtons));
    });

    testWidgets('the amount and currency sit near the middle of the screen', (
      tester,
    ) async {
      await _open(tester);
      final amount = tester.getCenter(find.byType(TextField)).dy;
      final currency = tester
          .getCenter(find.byType(DropdownButtonFormField<String>))
          .dy;
      for (final y in [amount, currency]) {
        expect(y, inInclusiveRange(_height * 0.4, _height * 0.6));
      }
    });

    testWidgets('with the keyboard open, the button stays above it', (
      tester,
    ) async {
      await _open(tester, keyboard: 300);
      expect(tester.takeException(), isNull);
      final button = tester.getRect(find.byType(PrimaryButton));
      expect(button.bottom, lessThanOrEqualTo(_height - 300));
    });

    testWidgets('a short phone can still reach everything', (tester) async {
      await _open(tester, height: 560, keyboard: 260);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(find.byType(PrimaryButton).hitTestable(), findsOneWidget);
    });
  });
}
