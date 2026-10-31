import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/today_refresher.dart';

void main() {
  Future<void> pumpToday(WidgetTester tester, DateTime Function() clock) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [clockProvider.overrideWithValue(clock)],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: TodayRefresher(
            child: Consumer(
              builder: (context, ref, _) =>
                  Text('${ref.watch(todayProvider).day}'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('moves to the new day when the app comes back to the front', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 29, 23, 30);
    await pumpToday(tester, () => now);
    expect(find.text('29'), findsOneWidget);

    now = DateTime(2026, 10, 30, 0, 5);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('moves on at midnight while the app stays open', (tester) async {
    var now = DateTime(2026, 10, 29, 23, 59, 50);
    await pumpToday(tester, () => now);
    expect(find.text('29'), findsOneWidget);

    now = DateTime(2026, 10, 30, 0, 0, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('30'), findsOneWidget);
  });
}
