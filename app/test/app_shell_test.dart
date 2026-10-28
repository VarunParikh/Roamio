import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/main.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RoamioApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on Home with the bottom bar', (tester) async {
    await pumpApp(tester);

    expect(find.text('Hey there 👋'), findsOneWidget);
    for (final label in ['Home', 'Split', 'You']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('bottom bar switches between tabs', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Split'));
    await tester.pumpAndSettle();
    expect(
      find.text('Who owes whom, without the awkward math.'),
      findsOneWidget,
    );

    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    expect(find.text('Your profile and privacy centre.'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Hey there 👋'), findsOneWidget);
  });

  testWidgets('shows a DEV banner in dev builds', (tester) async {
    await pumpApp(tester);

    expect(find.byType(Banner), findsOneWidget);
  });
}
