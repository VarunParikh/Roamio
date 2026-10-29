import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/consent/data/consent_service.dart';

import '../../support/fake_auth_service.dart';
import '../../support/fake_consent_service.dart';
import '../../support/fake_privacy_service.dart';
import '../../support/fake_profile_service.dart';
import '../../support/fake_share_files.dart';
import '../../support/fake_sync.dart';

Future<FakeAuthService> _openPrivacy(
  WidgetTester tester, {
  FakePrivacyService? privacy,
  FakeConsentService? consent,
  FakeProfileService? profile,
  SharedFiles? sharedFiles,
  FakeConnectivity? connectivity,
}) async {
  final auth = FakeAuthService(initial: readyFacts);
  await pumpRoamio(
    tester,
    auth,
    privacy: privacy,
    consent: consent,
    profile: profile,
    sharedFiles: sharedFiles,
    connectivity: connectivity,
  );
  await tester.tap(find.text('You'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Privacy centre'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Privacy centre'));
  await tester.pumpAndSettle();
  return auth;
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: _topList);
  // Built ahead of the viewport isn't on screen yet.
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The Privacy centre's list; the You page stays mounted underneath it.
Finder get _topList => find.byType(Scrollable).last;

Finder _button(String label) => find.widgetWithText(OutlinedButton, label);

LinkedChild _mia() =>
    LinkedChild(uid: 'mia', name: 'Mia', since: DateTime(2026, 10));

void main() {
  group('Privacy centre (UC-29)', () {
    testWidgets('downloads my data to the share sheet', (tester) async {
      final privacy = FakePrivacyService(photoParts: 2);
      final shared = SharedFiles();
      await _openPrivacy(tester, privacy: privacy, sharedFiles: shared);

      await tester.tap(find.text('Download my data'));
      await tester.pumpAndSettle();

      expect(privacy.calls, ['download:me']);
      expect(shared.files.map((f) => (f.$1, f.$2)), [
        ('Roamio data.json', 'application/json'),
        ('Roamio photos 1.zip', 'application/zip'),
        ('Roamio photos 2.zip', 'application/zip'),
      ]);
    });

    testWidgets('says why a download failed', (tester) async {
      final privacy = FakePrivacyService()
        ..failNext = 'Something went wrong. Please try again.';
      final shared = SharedFiles();
      await _openPrivacy(tester, privacy: privacy, sharedFiles: shared);

      await tester.tap(find.text('Download my data'));
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(shared.files, isEmpty);
    });

    testWidgets('a parent can download a linked child’s data (§7.3)', (
      tester,
    ) async {
      final privacy = FakePrivacyService();
      final shared = SharedFiles();
      await _openPrivacy(
        tester,
        privacy: privacy,
        sharedFiles: shared,
        consent: FakeConsentService()..children = [_mia()],
      );

      await _tapVisible(tester, find.text('Download Mia’s data'));

      expect(privacy.calls, ['download:mia']);
      expect(shared.files.single.$1, 'Mia’s Roamio data.json');
    });

    testWidgets('offline, downloading and deleting are off with a reason', (
      tester,
    ) async {
      final privacy = FakePrivacyService();
      await _openPrivacy(
        tester,
        privacy: privacy,
        connectivity: FakeConnectivity(online: false),
      );

      expect(
        tester
            .widget<PrimaryButton>(
              find.widgetWithText(PrimaryButton, 'Download my data'),
            )
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        _button('Delete my account'),
        300,
        scrollable: _topList,
      );
      expect(
        tester.widget<OutlinedButton>(_button('Delete my account')).enabled,
        isFalse,
      );
      expect(find.textContaining('Needs a connection'), findsWidgets);
    });

    testWidgets('deleting asks first, then deletes and signs out', (
      tester,
    ) async {
      final privacy = FakePrivacyService();
      final auth = await _openPrivacy(tester, privacy: privacy);

      await _tapVisible(tester, _button('Delete my account'));
      expect(find.text('Delete your account?'), findsOneWidget);
      expect(find.textContaining('Deleted user'), findsOneWidget);
      await tester.tap(find.text('Keep my account'));
      await tester.pumpAndSettle();
      expect(privacy.calls, isEmpty);

      await tester.tap(_button('Delete my account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(privacy.calls, ['delete:children=false']);
      expect(auth.calls, contains('signOut'));
    });

    testWidgets('a parent confirms their children keep their accounts', (
      tester,
    ) async {
      final privacy = FakePrivacyService();
      await _openPrivacy(
        tester,
        privacy: privacy,
        consent: FakeConsentService()..children = [_mia()],
      );

      await _tapVisible(tester, _button('Delete my account'));
      expect(find.textContaining('Mia keeps their account'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(privacy.calls, ['delete:children=true']);
    });

    testWidgets('a squad leader is told to hand over first', (tester) async {
      const why =
          'Make someone else squad leader of Goa before you delete your '
          'account.';
      final privacy = FakePrivacyService()..failNext = why;
      final auth = await _openPrivacy(tester, privacy: privacy);

      await _tapVisible(tester, _button('Delete my account'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text(why), findsOneWidget);
      expect(auth.calls, isNot(contains('signOut')));
    });

    testWidgets('lists the camera choice and saves it', (tester) async {
      final profile = FakeProfileService();
      await _openPrivacy(tester, profile: profile);

      await _tapVisible(tester, find.widgetWithText(SwitchListTile, 'Camera'));

      expect(profile.cameraSaved, [false]);
      expect(find.widgetWithText(SwitchListTile, 'Location'), findsOneWidget);
      expect(
        find.widgetWithText(SwitchListTile, 'Notifications'),
        findsOneWidget,
      );
    });

    testWidgets('shows how to correct data, nominate, and raise a concern', (
      tester,
    ) async {
      await _openPrivacy(tester);

      for (final heading in [
        'Correct your data',
        'Nominate a person',
        'Raise a concern',
      ]) {
        await tester.scrollUntilVisible(
          find.text(heading),
          300,
          scrollable: _topList,
        );
        expect(find.text(heading), findsOneWidget);
      }
      expect(find.textContaining('grievance@'), findsWidgets);
    });
  });
}
