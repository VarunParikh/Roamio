import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/config/phase2.dart';
import 'package:roamio/core/config/remote_config.dart';
import 'package:roamio/core/connectivity/connectivity_monitor.dart';
import 'package:roamio/core/data/categories.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/images/photo_pipeline.dart';
import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/features/adventures/data/activity_service.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/banners/data/banner_service.dart';
import 'package:roamio/features/budget/data/budget_service.dart';
import 'package:roamio/features/consent/data/consent_service.dart';
import 'package:roamio/features/home/data/weather_client.dart';
import 'package:roamio/features/home/data/weather_provider.dart';
import 'package:roamio/features/invites/data/invite_service.dart';
import 'package:roamio/features/invites/ui/invite_section.dart';
import 'package:roamio/features/invites/ui/invites_on_home.dart';
import 'package:roamio/features/notifications/data/notification_service.dart';
import 'package:roamio/features/profile/data/privacy_service.dart';
import 'package:roamio/features/profile/data/profile_service.dart';
import 'package:roamio/features/splits/data/fx_repository.dart';
import 'package:roamio/features/splits/data/settlement_service.dart';
import 'package:roamio/features/splits/ui/export_sheet.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/sync/sync_controller.dart';
import 'package:roamio/features/tabs/data/payment_memory.dart';
import 'package:roamio/features/tabs/data/receipt_scanner.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/payment_method.dart';
import 'package:roamio/features/updates/update_checker.dart';
import 'package:roamio/main.dart';

import 'fake_activity_service.dart';
import 'fake_adventure_service.dart';
import 'fake_banner_service.dart';
import 'fake_budget_service.dart';
import 'fake_consent_service.dart';
import 'fake_fx_repository.dart';
import 'fake_invite_service.dart';
import 'fake_location_service.dart';
import 'fake_notification_service.dart';
import 'fake_payment_memory.dart';
import 'fake_photo_pipeline.dart';
import 'fake_privacy_service.dart';
import 'fake_profile_service.dart';
import 'fake_receipt_scanner.dart';
import 'fake_settlement_service.dart';
import 'fake_share_files.dart';
import 'fake_squad_service.dart';
import 'fake_sync.dart';
import 'fake_tab_service.dart';
import 'fake_update_store.dart';

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
    required DateTime? dob,
  }) => _act(
    'create:$name:$email:'
    '${dob == null ? 'adult' : '${dob.year}-${dob.month}-${dob.day}'}',
  );

  @override
  Future<void> completeProfile({required DateTime? dob}) => _act(
    'complete:${dob == null ? 'adult' : '${dob.year}-${dob.month}-${dob.day}'}',
  );

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
  FxRepository? fx,
  String profileCurrency = 'INR',
  FakeProfileService? profile,
  FakeSettlementService? settlements,
  SharedFiles? sharedFiles,
  bool exportEnabled = true,
  FakeConnectivity? connectivity,
  FakeNetworkSwitch? network,
  FakeBudgetService? budgets,
  FakePrivacyService? privacy,
  FakeActivityService? activity,
  FetchJson? weatherFetch,
  bool weatherEnabled = true,
  UpdateChecker? updates,
  // Remembers Cash, so tests about other things can save a tab straight away.
  FakePaymentMemory? paymentMemory,
  Map<String, String>? remoteConfig,
  // Phase 2 features (under-18s, nominee) are off in the pilot app; most
  // feature tests still exercise them. Pilot tests pass `phase2: false`.
  bool phase2 = true,
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
        paymentMemoryProvider.overrideWithValue(
          paymentMemory ?? FakePaymentMemory(PaymentMethod.cash),
        ),
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
        fxRepositoryProvider.overrideWithValue(fx ?? FakeFxRepository()),
        settlementServiceProvider.overrideWithValue(
          settlements ?? FakeSettlementService(),
        ),
        shareFilesProvider.overrideWithValue(
          (sharedFiles ?? SharedFiles()).call,
        ),
        exportEnabledProvider.overrideWithValue(exportEnabled),
        budgetServiceProvider.overrideWithValue(budgets ?? FakeBudgetService()),
        profileServiceProvider.overrideWithValue(
          profile ?? FakeProfileService(currency: profileCurrency),
        ),
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
        connectivityMonitorProvider.overrideWithValue(
          connectivity ?? FakeConnectivity(),
        ),
        networkSwitchProvider.overrideWithValue(network ?? FakeNetworkSwitch()),
        photoFlushProvider.overrideWithValue(() async {}),
        activityServiceProvider.overrideWithValue(
          activity ?? FakeActivityService(),
        ),
        // Never the real network: unavailable unless a test answers.
        weatherClientProvider.overrideWithValue(
          WeatherClient(weatherFetch ?? (_) async => throw Exception('no web')),
        ),
        weatherEnabledProvider.overrideWithValue(weatherEnabled),
        // Remote Config unreachable: every in-app default applies.
        remoteConfigSourceProvider.overrideWithValue(
          remoteConfig == null
              ? const UnreachableRemoteConfig()
              : FixedRemoteConfig(remoteConfig),
        ),
        // GitHub unreachable unless a test passes [updates]: no popup.
        updateCheckerProvider.overrideWithValue(
          updates ??
              UpdateChecker(
                (_) async => throw Exception('no web'),
                FakeUpdateStore(),
              ),
        ),
        minorsEnabledProvider.overrideWithValue(phase2),
        nomineeEnabledProvider.overrideWithValue(phase2),
        photoUploadsEnabledProvider.overrideWithValue(phase2),
        privacyServiceProvider.overrideWithValue(
          privacy ?? FakePrivacyService(),
        ),
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

/// Remote Config that can't be reached, as on a first launch offline.
class UnreachableRemoteConfig implements RemoteConfigSource {
  const new();

  @override
  Future<Map<String, String>> load() async => throw Exception('offline');
}

/// Remote Config that answers with [values].
class FixedRemoteConfig implements RemoteConfigSource {
  const new(this.values);

  final Map<String, String> values;

  @override
  Future<Map<String, String>> load() async => values;
}
