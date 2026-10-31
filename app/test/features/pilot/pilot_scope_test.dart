import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/banners/ui/adventure_banner.dart';
import 'package:roamio/features/consent/data/consent_service.dart';
import 'package:roamio/features/tabs/ui/memories.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_consent_service.dart';
import '../../support/fake_photo_pipeline.dart';
import '../../support/fake_receipt_scanner.dart';
import '../../support/fake_tab_service.dart';

/// The Android pilot is for adults only: under-18 accounts, parental
/// consent and nominating a person come back in Phase 2 with the web app
/// (owner, 2026-10-30). Their code stays; these switches hide them.
void main() {
  uploadsOff();
  const tick = 'I’m 18 or older and I’ve read the ';

  testWidgets('email sign-up asks no birth date; the 18+ tick is recorded', (
    tester,
  ) async {
    final auth = FakeAuthService();
    await pumpRoamio(tester, auth, phase2: false);
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Date of birth'), findsNothing);
    expect(find.text(tick), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your name'),
      'Ari',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'ari@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret123',
    );
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    // Without the tick nothing happens, with a reason.
    expect(
      find.text(
        'Please confirm you’re 18 or older and accept the privacy '
        'notice.',
      ),
      findsOneWidget,
    );
    expect(auth.calls, isEmpty);

    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(auth.calls, ['create:Ari:ari@example.com:adult']);
  });

  testWidgets('a Google sign-in just confirms 18+ and the notice', (
    tester,
  ) async {
    final auth = FakeAuthService(initial: const SessionFacts(uid: 'u'));
    await pumpRoamio(tester, auth, phase2: false);

    expect(find.text('Date of birth'), findsNothing);
    expect(find.textContaining('under-18'), findsNothing);
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(auth.calls, ['complete:adult']);
  });

  testWidgets('no Linked children on You, and no child downloads or '
      'nominee in the Privacy centre', (tester) async {
    await pumpRoamio(
      tester,
      FakeAuthService(initial: readyFacts),
      phase2: false,
      consent: FakeConsentService()
        ..children = [const LinkedChild(uid: 'mia', name: 'Mia', since: null)],
    );
    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Privacy centre'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Linked children', skipOffstage: false), findsNothing);

    await tester.tap(find.text('Privacy centre'));
    await tester.pumpAndSettle();
    final list = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Delete my account'),
      300,
      scrollable: list,
    );
    expect(find.text('Nominate a person', skipOffstage: false), findsNothing);
    expect(find.text('Download Mia’s data', skipOffstage: false), findsNothing);
    expect(find.text('Linked children', skipOffstage: false), findsNothing);
  });
}

/// Phase 1 uploads no pictures (spec §10, owner 2026-10-31).
void uploadsOff() {
  final trip = Adventure(
    id: 'goa',
    name: 'Goa trip',
    countryCode: 'IN',
    startDate: DateTime(2026, 10, 20),
    endDate: DateTime(2026, 11, 3),
    baseCurrency: 'INR',
    leaderUid: 'ari',
    memberUids: const ['ari'],
  );

  Future<FakePhotoPipeline> open(
    WidgetTester tester,
    String location, {
    String billText = 'CAFE GOA\nTOTAL 450.00\n27/10/2026',
    FakeTabService? tabs,
  }) async {
    final photos = FakePhotoPipeline();
    await pumpRoamio(
      tester,
      FakeAuthService(initial: readyFacts),
      adventures: FakeAdventureService([trip]),
      photos: photos,
      tabs: tabs,
      scanner: FakeReceiptScanner(billText),
      phase2: false,
    );
    unawaited(
      GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location),
    );
    await tester.pumpAndSettle();
    return photos;
  }

  group('no uploads in the pilot', () {
    testWidgets('Edit adventure has no own banner photo, only the country’s', (
      tester,
    ) async {
      await open(tester, '/adventures/goa/edit');
      expect(find.text('Edit adventure'), findsOneWidget);
      expect(find.text('Use my own photo'), findsNothing);
      expect(find.byType(AdventureBanner), findsWidgets);
    });

    testWidgets('Add tab has no photos', (tester) async {
      await open(tester, '/adventures/goa/tabs/new');
      expect(find.byType(MemoriesPicker), findsNothing);
      expect(find.text('Add photo', skipOffstage: false), findsNothing);
      expect(find.text('Photos', skipOffstage: false), findsNothing);
    });

    testWidgets(
      'Scan bill reads on the phone, keeps nothing, uploads nothing',
      (tester) async {
        final tabs = FakeTabService();
        final photos = await open(
          tester,
          '/adventures/goa/tabs/new',
          tabs: tabs,
        );
        await tester.tap(find.text('Scan bill'));
        await tester.pumpAndSettle();

        expect(
          find.text('Check the amount, date and name we read.'),
          findsOneWidget,
        );
        expect(photos.discarded, ['/photos/1.jpg']);

        final food = find.textContaining('Food & Dining');
        await tester.ensureVisible(food);
        await tester.pumpAndSettle();
        await tester.tap(food);
        await tester.pumpAndSettle();
        final save = find.widgetWithText(PrimaryButton, 'Save tab');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(tabs.added, hasLength(1));
        expect(photos.queued, isEmpty);
      },
    );

    testWidgets('a bill it can’t read is thrown away too', (tester) async {
      final photos = await open(
        tester,
        '/adventures/goa/tabs/new',
        billText: 'no numbers here',
      );
      await tester.tap(find.text('Scan bill'));
      await tester.pumpAndSettle();
      expect(photos.discarded, ['/photos/1.jpg']);
    });
  });
}
