import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_notification_service.dart';

Adventure _trip({String leader = 'ari'}) => Adventure(
  id: 'bkk',
  name: 'Bangkok trip',
  countryCode: 'TH',
  startDate: DateTime(2026, 12),
  endDate: DateTime(2026, 12, 8),
  baseCurrency: 'THB',
  leaderUid: leader,
  memberUids: const ['ari', 'cara'],
);

Future<FakeNotificationService> _home(
  WidgetTester tester, {
  bool? answer,
  bool allow = true,
  String leader = 'ari',
}) async {
  final notifications = FakeNotificationService(answer: answer, allow: allow);
  await pumpRoamio(
    tester,
    FakeAuthService(initial: readyFacts),
    adventures: FakeAdventureService([_trip(leader: leader)]),
    notifications: notifications,
  );
  return notifications;
}

void main() {
  group('asking leads about push (spec UC-14, consent per purpose)', () {
    testWidgets('a lead who was never asked can turn it on', (tester) async {
      final n = await _home(tester);

      expect(find.text('Know when friends join'), findsOneWidget);
      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();

      expect(n.calls, contains('turnOn'));
      expect(find.text('Know when friends join'), findsNothing);
    });

    testWidgets('Not now is remembered', (tester) async {
      final n = await _home(tester);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(n.calls, contains('decline'));
      expect(find.text('Know when friends join'), findsNothing);
    });

    testWidgets('says so when Android refuses', (tester) async {
      await _home(tester, allow: false);
      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Notifications are off'), findsOneWidget);
    });

    testWidgets('not shown once answered, or to non-leads', (tester) async {
      await _home(tester, answer: false);
      expect(find.text('Know when friends join'), findsNothing);
    });

    testWidgets('not shown to someone who leads nothing', (tester) async {
      await _home(tester, leader: 'cara');
      expect(find.text('Know when friends join'), findsNothing);
    });

    testWidgets('re-registers the phone on start when already on', (
      tester,
    ) async {
      final n = await _home(tester, answer: true);
      expect(n.calls, ['refresh']);
    });
  });
}
