import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/data/categories.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/images/photo_pipeline.dart';
import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/banners/data/banner_service.dart';
import 'package:roamio/features/consent/data/consent_service.dart';
import 'package:roamio/features/invites/data/invite_service.dart';
import 'package:roamio/features/invites/ui/invite_section.dart';
import 'package:roamio/features/invites/ui/invites_on_home.dart';
import 'package:roamio/features/notifications/data/notification_service.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/tabs/data/receipt_scanner.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/main.dart';

import 'fake_adventure_service.dart';
import 'fake_banner_service.dart';
import 'fake_consent_service.dart';
import 'fake_invite_service.dart';
import 'fake_location_service.dart';
import 'fake_notification_service.dart';
import 'fake_photo_pipeline.dart';
import 'fake_receipt_scanner.dart';
import 'fake_squad_service.dart';
import 'fake_tab_service.dart';

/// In-memory [AuthService]: tests push [SessionFacts] and inspect [calls].
class FakeAuthService implements AuthService {
  new({SessionFacts initial = const SessionFacts.signedOut()})
    : _facts = initial;

  SessionFacts _facts;
  final _changes = StreamController<SessionFacts>.broadcast();
  final List<String> calls = [];

  /// When set, the next action throws this failure.
  AuthFailure? failNext;
  bool verified = false;

  void emit(SessionFacts facts) {
    _facts = facts;
    _changes.add(facts);
  }

  Future<void> _act(String call) async {
    calls.add(call);
    final failure = failNext;
    failNext = null;
    if (failure != null) throw AuthException(failure);
  }

  @override
  Stream<SessionFacts> session() async* {
    yield _facts;
    yield* _changes.stream;
  }

  @override
  String? get email => 'ari@example.com';

  @override
  String? get displayName => 'Ari Chen';

  @override
  Future<void> signInWithGoogle() => _act('google');

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _act('email:$email');

  @override
  Future<void> sendPasswordReset(String email) => _act('reset:$email');

  @override
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
    required DateTime dob,
  }) => _act('create:$name:$email:${dob.year}-${dob.month}-${dob.day}');

  @override
  Future<void> completeProfile({required DateTime dob}) =>
      _act('complete:${dob.year}-${dob.month}-${dob.day}');

  @override
  Future<void> sendVerificationEmail() => _act('resend');

  @override
  Future<bool> refreshUser() async {
    await _act('refresh');
    return verified;
  }

  @override
  Future<void> signOut() => _act('signOut');

  @override
  Future<void> deleteCurrentUser() => _act('delete');
}

const readyFacts = SessionFacts(
  uid: 'ari',
  hasAccount: true,
  ageStatus: 'adult',
);

/// The real bundled countries, read straight from disk: a large asset loads
/// on a background isolate, which widget tests' fake clock never advances.
final testCountries = Countries(
  (jsonDecode(File('assets/data/countries.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>()
      .map(Country.fromJson)
      .toList(),
);

/// The bundled tab categories, read from disk like [testCountries].
final List<Category> testCategories = (jsonDecode(
  File('assets/data/categories.json').readAsStringSync(),
) as List).cast<Map<String, dynamic>>().map(Category.fromJson).toList();

/// Pumps the whole app with [auth] and a fixed "today" of 29 Oct 2026.
/// Pass `settle: false` on the splash screen, whose spinner never settles.
Future<void> pumpRoamio(
  WidgetTester tester,
  FakeAuthService auth, {
  bool settle = true,
  FakeConsentService? consent,
  FakeAdventureService? adventures,
  FakeBannerService? banners,
  List<Uri>? openedLinks,
  FakeInviteService? invites,
  List<String>? shared,
  String? clipboard,
  FakeSquadService? squad,
  FakeTabService? tabs,
  FakeNotificationService? notifications,
  FakePhotoPipeline? photos,
  FakeLocationService? location,
  FakeReceiptScanner? scanner,
  bool ocrEnabled = true,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        countriesProvider.overrideWith((ref) => testCountries),
        categoriesProvider.overrideWith((ref) => testCategories),
        tabServiceProvider.overrideWithValue(tabs ?? FakeTabService()),
        notificationServiceProvider.overrideWithValue(
          notifications ?? FakeNotificationService(answer: false),
        ),
        photoPipelineProvider.overrideWithValue(photos ?? FakePhotoPipeline()),
        locationServiceProvider.overrideWithValue(
          location ?? FakeLocationService(),
        ),
        receiptScannerProvider.overrideWithValue(
          scanner ?? FakeReceiptScanner(),
        ),
        ocrEnabledProvider.overrideWithValue(ocrEnabled),
        bannerServiceProvider.overrideWithValue(banners ?? FakeBannerService()),
        openLinkProvider.overrideWithValue(
          (uri) async => openedLinks?.add(uri),
        ),
        adventureServiceProvider.overrideWithValue(
          adventures ?? FakeAdventureService(),
        ),
        inviteServiceProvider.overrideWithValue(invites ?? FakeInviteService()),
        squadServiceProvider.overrideWithValue(squad ?? FakeSquadService()),
        shareTextProvider.overrideWithValue((text) async => shared?.add(text)),
        readClipboardProvider.overrideWithValue(() async => clipboard),
        consentServiceProvider.overrideWithValue(
          consent ?? FakeConsentService(),
        ),
        todayProvider.overrideWithValue(DateTime(2026, 10, 29)),
      ],
      child: const RoamioApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
}
