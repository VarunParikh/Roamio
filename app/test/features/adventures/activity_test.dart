import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/data/activity_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/squad/data/squad_service.dart';

import '../../support/fake_activity_service.dart';
import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_squad_service.dart';

ActivityEntry _e(
  String type, {
  String actor = 'bob',
  String subject = 'cara',
  String? tab,
  String? reason,
}) => ActivityEntry(
  id: type,
  type: type,
  actorUid: actor,
  subject: subject,
  createdAt: DateTime(2026, 10, 28, 9),
  tabDescription: tab,
  reason: reason,
);

String? _say(ActivityEntry e) => describeActivity(
  e,
  myUid: 'ari',
  who: (id) {
    return const {'bob': 'Bob Lee', 'cara': 'Cara Diaz', 'ari': 'Ari'}[id] ??
        deletedUserName;
  },
);

final _goa = Adventure(
  id: 'goa',
  name: 'Goa trip',
  countryCode: 'IN',
  startDate: DateTime(2026, 10, 20),
  endDate: DateTime(2026, 11, 2),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari', 'bob'],
);

void main() {
  group('activity lines (UC-22, UC-26a, UC-32)', () {
    test('squad changes', () {
      expect(
        _say(_e('member_joined', subject: 'bob')),
        'Bob Lee joined the squad',
      );
      expect(_say(_e('member_left', subject: 'bob')), 'Bob Lee left the squad');
      expect(_say(_e('member_removed')), 'Bob Lee removed Cara Diaz');
      expect(_say(_e('co_lead_added')), 'Bob Lee made Cara Diaz a co-lead');
      expect(
        _say(_e('co_lead_removed')),
        'Bob Lee made Cara Diaz a member again',
      );
      expect(
        _say(_e('leader_changed')),
        'Bob Lee handed squad leadership to Cara Diaz',
      );
    });

    test('tabs and payments, naming the tab', () {
      expect(
        _say(_e('tab_deleted', subject: 't1', tab: 'Dinner')),
        'Bob Lee deleted “Dinner”',
      );
      expect(
        _say(_e('tab_edit_replaced', subject: 't1', tab: 'Dinner')),
        'Bob Lee’s offline edit replaced a newer change to “Dinner”',
      );
      expect(
        _say(
          _e(
            'tab_rejected',
            subject: 't1',
            tab: 'Taxi',
            reason: "payments don't add up to the amount",
          ),
        ),
        "“Taxi” was removed: payments don't add up to the amount",
      );
      expect(_say(_e('settlement_recorded')), 'Bob Lee recorded a payment');
      expect(_say(_e('settlement_undone')), 'Bob Lee undid a payment');
      // A tab that can't be read any more.
      expect(_say(_e('tab_deleted', subject: 't9')), 'Bob Lee deleted a tab');
    });

    test('you are "You", and deleted accounts are "Deleted user"', () {
      expect(
        _say(_e('tab_edit_replaced', actor: 'ari', tab: 'Dinner')),
        'Your offline edit replaced a newer change to “Dinner”',
      );
      expect(
        _say(_e('member_left', subject: 'zed')),
        'Deleted user left the squad',
      );
      expect(_say(_e('something_new')), isNull);
    });
  });

  group('Activity screen', () {
    Future<void> open(WidgetTester tester, FakeActivityService activity) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        adventures: FakeAdventureService([_goa]),
        squad: FakeSquadService()
          ..names.addAll({'ari': 'Ari', 'bob': 'Bob Lee'}),
        activity: activity,
      );
      await tester.tap(find.text('Goa trip'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Activity'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.text('Activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists what happened, newest first', (tester) async {
      await open(
        tester,
        FakeActivityService({
          'goa': [
            _e('tab_edit_replaced', subject: 't1', tab: 'Dinner'),
            _e('member_joined', subject: 'bob'),
          ],
        }),
      );

      expect(
        find.text('Bob Lee’s offline edit replaced a newer change to “Dinner”'),
        findsOneWidget,
      );
      expect(find.text('Bob Lee joined the squad'), findsOneWidget);
    });

    testWidgets('empty: says so', (tester) async {
      await open(tester, FakeActivityService({}));
      expect(find.text('Nothing has happened yet.'), findsOneWidget);
    });
  });
}
