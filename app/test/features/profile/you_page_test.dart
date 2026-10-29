import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/profile/data/profile_service.dart';

import '../../support/fake_auth_service.dart';
import '../../support/fake_notification_service.dart';
import '../../support/fake_photo_pipeline.dart';
import '../../support/fake_profile_service.dart';

Future<void> _openYou(
  WidgetTester tester, {
  FakeProfileService? profile,
  FakeNotificationService? notifications,
  FakePhotoPipeline? photos,
  SessionFacts facts = readyFacts,
}) async {
  await pumpRoamio(
    tester,
    FakeAuthService(initial: facts),
    profile: profile,
    notifications: notifications,
    photos: photos,
  );
  await tester.tap(find.text('You'));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextField, label);

Finder _switch(String label) =>
    find.widgetWithText(SwitchListTile, label, skipOffstage: false);

void main() {
  group('You page (UC-28)', () {
    testWidgets('shows who you are, in your currency', (tester) async {
      await _openYou(tester, profile: FakeProfileService(currency: 'THB'));

      expect(find.text('Your profile'), findsOneWidget);
      expect(
        tester.widget<TextField>(_field('Name')).controller!.text,
        'Ari Chen',
      );
      expect(
        tester.widget<TextField>(_field('About you')).controller!.text,
        'Always lost',
      );
      expect(find.text('THB'), findsWidgets);
    });

    testWidgets('saves a new name and description, trimmed', (tester) async {
      final profile = FakeProfileService();
      await _openYou(tester, profile: profile);

      await tester.enterText(_field('Name'), '  Ari C.  ');
      await tester.enterText(_field('About you'), 'Found the way');
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();

      expect(profile.saved, ['Ari C. | Found the way']);
    });

    testWidgets('won’t save without a name', (tester) async {
      final profile = FakeProfileService();
      await _openYou(tester, profile: profile);

      await tester.enterText(_field('Name'), '   ');
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();

      expect(profile.saved, isEmpty);
      expect(find.text('Add your name so your squad knows you.'), findsOne);
    });

    testWidgets('changing the profile currency saves at once', (tester) async {
      final profile = FakeProfileService();
      await _openYou(tester, profile: profile);

      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('IDR').last);
      await tester.pumpAndSettle();

      expect(profile.currencySaved, ['IDR']);
    });

    testWidgets('a new photo is compressed and queued as your avatar', (
      tester,
    ) async {
      final photos = FakePhotoPipeline();
      await _openYou(tester, photos: photos);

      await tester.tap(find.byTooltip('Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();

      expect(photos.picks, [false]);
      expect(photos.queued.single, contains('users/ari/avatar'));
      expect(photos.queued.single, contains('users/ari.photoUrl replace'));
    });

    testWidgets('cancelling the picker queues nothing', (tester) async {
      final photos = FakePhotoPipeline()..cancelNext = true;
      await _openYou(tester, photos: photos);

      await tester.tap(find.byTooltip('Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();

      expect(photos.queued, isEmpty);
    });
  });

  group('toggles (UC-28, spec §8)', () {
    testWidgets('notifications: on asks Android, off records no', (
      tester,
    ) async {
      final notifications = FakeNotificationService(answer: false);
      await _openYou(tester, notifications: notifications);

      await tester.tap(_switch('Notifications'));
      await tester.pumpAndSettle();
      expect(notifications.calls, contains('turnOn'));
      expect(
        tester.widget<SwitchListTile>(_switch('Notifications')).value,
        isTrue,
      );

      await tester.tap(_switch('Notifications'));
      await tester.pumpAndSettle();
      expect(notifications.calls.last, 'decline');
      expect(
        tester.widget<SwitchListTile>(_switch('Notifications')).value,
        isFalse,
      );
    });

    testWidgets('notifications stay off if Android says no', (tester) async {
      final notifications = FakeNotificationService(
        answer: false,
        allow: false,
      );
      await _openYou(tester, notifications: notifications);

      await tester.tap(_switch('Notifications'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<SwitchListTile>(_switch('Notifications')).value,
        isFalse,
      );
      expect(
        find.text(
          'Notifications are off. You can allow them in settings later.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('adults can switch location on and off', (tester) async {
      final profile = FakeProfileService();
      await _openYou(tester, profile: profile);

      await tester.tap(_switch('Location'));
      await tester.pumpAndSettle();
      await tester.tap(_switch('Location'));
      await tester.pumpAndSettle();

      expect(profile.locationSaved, [true, false]);
    });

    testWidgets('under-18 accounts have location off, with the reason', (
      tester,
    ) async {
      final profile = FakeProfileService(
        profile: const Profile(name: 'Mia'),
        location: true, // even a stale "on" is shown off
      );
      await _openYou(
        tester,
        profile: profile,
        facts: const SessionFacts(
          uid: 'mia',
          hasAccount: true,
          ageStatus: 'minor_active',
        ),
      );

      final tile = tester.widget<SwitchListTile>(_switch('Location'));
      expect(tile.value, isFalse);
      expect(tile.onChanged, isNull);
      expect(
        find.text('Location is always off for under-18 accounts.'),
        findsOne,
      );
      expect(profile.locationSaved, isEmpty);
    });
  });

  testWidgets('Linked children and Sign out are still there', (tester) async {
    await _openYou(tester);
    await tester.scrollUntilVisible(
      find.text('Sign out'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sign out'), findsOneWidget);
  });
}
