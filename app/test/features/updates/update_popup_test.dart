import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/updates/update_checker.dart';

import '../../support/fake_auth_service.dart';
import '../../support/fake_update_store.dart';

UpdateChecker _github(FakeUpdateStore store, {bool down = false}) =>
    UpdateChecker((uri) async {
      if (down) throw Exception('offline');
      return {
        'tag_name': 'v9.0.0',
        'body': 'Faster Split screen.',
        'html_url': 'https://github.com/VarunParikh/Roamio/releases/tag/v9.0.0',
        'assets': [
          {
            'name': 'roamio.apk',
            'browser_download_url': 'https://dl/roamio.apk',
          },
        ],
      };
    }, store);

void main() {
  group('Update popup (UC-34)', () {
    testWidgets('a newer release: notes, Download update, or Later', (
      tester,
    ) async {
      final store = FakeUpdateStore();
      final opened = <Uri>[];
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        updates: _github(store),
        openedLinks: opened,
      );

      expect(find.text('Update available'), findsOneWidget);
      expect(find.textContaining('9.0.0'), findsWidgets);
      expect(find.text('Faster Split screen.'), findsOneWidget);

      await tester.tap(find.text('Download update'));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://dl/roamio.apk')]);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);
      expect(store.saved['dismissed'], '9.0.0');
    });

    testWidgets('below min_supported_version it can’t be dismissed', (
      tester,
    ) async {
      await pumpRoamio(
        tester,
        FakeAuthService(initial: readyFacts),
        updates: _github(FakeUpdateStore(), down: true),
        remoteConfig: const {'min_supported_version': '9.0.0'},
      );

      expect(find.text('Update needed'), findsOneWidget);
      expect(find.text('Later'), findsNothing);
      expect(find.text('Download update'), findsOneWidget);

      // Neither the back button nor a tap outside closes it.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Update needed'), findsOneWidget);
    });

    testWidgets('up to date: no popup', (tester) async {
      await pumpRoamio(tester, FakeAuthService(initial: readyFacts));
      expect(find.text('Update available'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
