import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/theme/roamio_theme.dart';
import 'package:roamio/core/ui/bottom_bar.dart';

void main() {
  const items = [
    BottomBarItem(icon: Icons.home, label: 'Home'),
    BottomBarItem(icon: Icons.pie_chart, label: 'Split'),
  ];

  Future<List<int>> pumpBar(WidgetTester tester, {int current = 0}) async {
    final taps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoamioTheme(),
        home: Scaffold(
          bottomNavigationBar: RoamioBottomBar(
            items: items,
            currentIndex: current,
            onSelected: taps.add,
          ),
        ),
      ),
    );
    return taps;
  }

  testWidgets('reports the tapped index', (tester) async {
    final taps = await pumpBar(tester);

    await tester.tap(find.text('Split'));

    expect(taps, [1]);
  });

  testWidgets('marks only the current item as selected for TalkBack', (
    tester,
  ) async {
    await pumpBar(tester, current: 1);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Split')),
      isSemantics(isSelected: true, isButton: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Home')),
      isSemantics(isSelected: false, isButton: true),
    );
  });

  testWidgets('tap targets are at least 48dp tall', (tester) async {
    await pumpBar(tester);

    expect(
      tester.getSize(find.byType(AnimatedContainer).first).height,
      greaterThanOrEqualTo(48),
    );
  });
}
