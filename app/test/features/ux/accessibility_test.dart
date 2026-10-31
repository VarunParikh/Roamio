import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_tab_service.dart';

/// Spec §12: touch targets ≥ 48 dp, labels on every control, text
/// contrast ≥ 4.5:1. Checked on each main screen.
final _goa = Adventure(
  id: 'bkk',
  name: 'Goa trip',
  countryCode: 'IN',
  city: 'Panaji',
  startDate: DateTime(2026, 10, 20),
  endDate: DateTime(2026, 11, 2),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari'],
);

Future<void> _meetsGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

Future<void> _open(
  WidgetTester tester,
  String location, {
  List<Adventure> adventures = const [],
  SessionFacts facts = readyFacts,
}) async {
  await pumpRoamio(
    tester,
    FakeAuthService(initial: facts),
    adventures: FakeAdventureService(adventures),
  );
  if (location != '/') {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
  }
}

void main() {
  final screens = <String, (String, List<Adventure>, String)>{
    'Home, empty': ('/', const [], 'New Adventure'),
    'Home, with an adventure': ('/', [_goa], 'Goa trip'),
    'Adventure page': ('/adventures/bkk', [_goa], 'Add tab'),
    'Add tab': ('/adventures/bkk/tabs/new', [_goa], 'Amount'),
    'Activity': ('/adventures/bkk/activity', [_goa], 'Back to the adventure'),
    'Split': ('/split', [_goa], 'Goa trip'),
    'You': ('/you', const [], 'Your profile'),
    'Privacy centre': ('/privacy', const [], 'Download my data'),
  };
  for (final MapEntry(key: name, value: (location, adventures, shows))
      in screens.entries) {
    testWidgets(name, (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester, location, adventures: adventures);
      expect(find.textContaining(shows), findsWidgets);
      await _meetsGuidelines(tester);
      semantics.dispose();
    });
  }

  testWidgets('Split with tabs and the breakdown open', (tester) async {
    final semantics = tester.ensureSemantics();
    final trip = Adventure(
      id: 'bkk',
      name: 'Goa trip',
      countryCode: 'IN',
      startDate: DateTime(2026, 10, 20),
      endDate: DateTime(2026, 11, 2),
      baseCurrency: 'INR',
      leaderUid: 'ari',
      memberUids: const ['ari', 'ben'],
    );
    await pumpRoamio(
      tester,
      FakeAuthService(initial: readyFacts),
      adventures: FakeAdventureService([trip]),
      tabs: FakeTabService([
        TabEntry(
          id: 't',
          description: 'Dinner',
          category: 'food_dining',
          date: DateTime(2026, 10, 27),
          createdBy: 'ben',
          split: TabSplit(
            amount: Money(100000, 'INR'),
            payers: const [Payment('ben', 100000)],
            participants: const ['ari', 'ben'],
            fxDate: '2026-10-27',
          ),
        ),
      ]),
    );
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/split');
    await tester.pumpAndSettle();
    final open = find.text('See detailed breakdown');
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.text('Spend by day'), findsOneWidget);
    await _meetsGuidelines(tester);
    semantics.dispose();
  });

  testWidgets('Sign in', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpRoamio(tester, FakeAuthService(), settle: false);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('Google'), findsWidgets);
    await _meetsGuidelines(tester);
    semantics.dispose();
  });
}
