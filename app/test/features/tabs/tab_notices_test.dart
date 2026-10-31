import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_page.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/home/ui/needs_you.dart';
import 'package:roamio/features/tabs/data/tab_notice_service.dart';
import 'package:roamio/features/tabs/ui/tab_detail.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_tab_notice_service.dart';
import '../../support/fake_tab_service.dart';

/// Ari leads, Bob is a member.
Adventure _trip(String id, String name) => Adventure(
  id: id,
  name: name,
  countryCode: 'TH',
  startDate: DateTime(2026, 10),
  endDate: DateTime(2026, 12, 8),
  baseCurrency: 'THB',
  leaderUid: 'ari',
  memberUids: const ['ari', 'bob'],
);

TabNotice _waiting(String tab, {String adventure = 'bkk'}) => TabNotice(
  id: '${adventure}_tabwaiting_$tab',
  kind: TabNoticeKind.waiting,
  adventureId: adventure,
  tabId: tab,
);

TabNotice _rejected(String tab, {String description = 'Dinner'}) => TabNotice(
  id: 'bkk_tabrejected_$tab',
  kind: TabNoticeKind.rejected,
  adventureId: 'bkk',
  tabId: tab,
  description: description,
);

Future<FakeTabNoticeService> _home(
  WidgetTester tester, {
  required String as,
  required List<TabNotice> notices,
  List<Adventure>? adventures,
}) async {
  final service = FakeTabNoticeService(notices);
  await pumpRoamio(
    tester,
    FakeAuthService(
      initial: SessionFacts(uid: as, hasAccount: true, ageStatus: 'adult'),
    ),
    adventures: FakeAdventureService(
      adventures ?? [_trip('bkk', 'Bangkok trip')],
    ),
    tabs: FakeTabService(),
    tabNotices: service,
  );
  return service;
}

void main() {
  group('waiting tabs on Home (spec UC-21a)', () {
    testWidgets('counts them per adventure, in the singular too', (
      tester,
    ) async {
      await _home(
        tester,
        as: 'ari',
        adventures: [_trip('bkk', 'Bangkok trip'), _trip('goa', 'Goa trip')],
        notices: [
          _waiting('t1'),
          _waiting('t2'),
          _waiting('t3', adventure: 'goa'),
        ],
      );
      expect(find.text('2 tabs to approve'), findsOneWidget);
      expect(find.text('1 tab to approve'), findsOneWidget);
      expect(find.text('🎒 Bangkok trip'), findsOneWidget);
      expect(find.text('🎒 Goa trip'), findsOneWidget);
    });

    testWidgets('opens that adventure', (tester) async {
      await _home(
        tester,
        as: 'ari',
        adventures: [_trip('bkk', 'Bangkok trip'), _trip('goa', 'Goa trip')],
        notices: [_waiting('t1', adventure: 'goa')],
      );
      await tester.tap(find.text('See tabs'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AdventurePage>(find.byType(AdventurePage)).adventureId,
        'goa',
      );
    });

    testWidgets('goes down and away as tabs are decided', (tester) async {
      final service = await _home(
        tester,
        as: 'ari',
        notices: [_waiting('t1'), _waiting('t2')],
      );
      service.decide('t1');
      await tester.pumpAndSettle();
      expect(find.text('1 tab to approve'), findsOneWidget);
      service.decide('t2');
      await tester.pumpAndSettle();
      expect(find.textContaining('to approve'), findsNothing);
    });

    testWidgets('has no dismiss: only deciding clears it', (tester) async {
      await _home(tester, as: 'ari', notices: [_waiting('t1')]);
      expect(
        find.descendant(
          of: find.byType(NeedsYou),
          matching: find.byIcon(Icons.close),
        ),
        findsNothing,
      );
    });

    testWidgets('hidden from someone no longer an admin', (tester) async {
      await _home(tester, as: 'bob', notices: [_waiting('t1')]);
      expect(find.textContaining('to approve'), findsNothing);
    });

    testWidgets('hidden for an adventure the person has left', (tester) async {
      await _home(
        tester,
        as: 'ari',
        notices: [_waiting('t1', adventure: 'gone')],
      );
      expect(find.textContaining('to approve'), findsNothing);
    });
  });

  group('a rejected tab on Home (spec UC-21a)', () {
    testWidgets('tells the creator and opens the tab', (tester) async {
      await _home(tester, as: 'bob', notices: [_rejected('t1')]);
      expect(find.text('Your tab was rejected'), findsOneWidget);
      expect(find.text('Dinner · 🎒 Bangkok trip'), findsOneWidget);
      await tester.tap(find.text('See tab'));
      await tester.pumpAndSettle();
      final detail = tester.widget<TabDetailScreen>(
        find.byType(TabDetailScreen),
      );
      expect(detail.adventureId, 'bkk');
      expect(detail.tabId, 't1');
    });

    testWidgets('a tab with no description just names the adventure', (
      tester,
    ) async {
      await _home(
        tester,
        as: 'bob',
        notices: [_rejected('t1', description: '')],
      );
      expect(find.text('🎒 Bangkok trip'), findsOneWidget);
    });

    testWidgets('can be dismissed', (tester) async {
      final service = await _home(
        tester,
        as: 'bob',
        notices: [_rejected('t1')],
      );
      await tester.tap(find.byTooltip('Dismiss rejected tab'));
      await tester.pumpAndSettle();
      expect(service.dismissed, ['bkk_tabrejected_t1']);
      expect(find.text('Your tab was rejected'), findsNothing);
    });

    testWidgets('goes when the tab is resubmitted or deleted', (tester) async {
      final service = await _home(
        tester,
        as: 'bob',
        notices: [_rejected('t1')],
      );
      service.decide('t1');
      await tester.pumpAndSettle();
      expect(find.text('Your tab was rejected'), findsNothing);
    });
  });

  testWidgets('long names fit a small phone', (tester) async {
    final service = FakeTabNoticeService([_waiting('t1'), _rejected('t2')]);
    await pumpRoamio(
      tester,
      FakeAuthService(
        initial: const SessionFacts(
          uid: 'ari',
          hasAccount: true,
          ageStatus: 'adult',
        ),
      ),
      adventures: FakeAdventureService([
        _trip('bkk', 'College group Bangkok adventure with everyone we know'),
      ]),
      tabs: FakeTabService(),
      tabNotices: service,
    );
    tester.view.physicalSize = const Size(360 * 2.625, 640 * 2.625);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
