import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:roamio/core/config/flavor.dart';
import 'package:roamio/core/config/phase2.dart';
import 'package:roamio/core/config/remote_config.dart';
import 'package:roamio/core/connectivity/connectivity_monitor.dart';
import 'package:roamio/core/crash/crash_reporter.dart';
import 'package:roamio/core/firebase/firebase_setup.dart';
import 'package:roamio/core/images/photo_pipeline.dart';
import 'package:roamio/core/router/app_router.dart';
import 'package:roamio/core/theme/roamio_theme.dart';
import 'package:roamio/features/adventures/data/activity_service.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/data/firebase_activity_service.dart';
import 'package:roamio/features/adventures/data/firebase_adventure_service.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/data/firebase_auth_service.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/auth/ui/today_refresher.dart';
import 'package:roamio/features/banners/data/banner_service.dart';
import 'package:roamio/features/banners/data/firebase_banner_service.dart';
import 'package:roamio/features/consent/data/consent_service.dart';
import 'package:roamio/features/consent/data/firebase_consent_service.dart';
import 'package:roamio/features/home/data/home_card_memory.dart';
import 'package:roamio/features/home/data/weather_client.dart';
import 'package:roamio/features/invites/data/firebase_invite_service.dart';
import 'package:roamio/features/invites/data/invite_service.dart';
import 'package:roamio/features/invites/ui/invite_section.dart';
import 'package:roamio/features/notifications/data/firebase_notification_service.dart';
import 'package:roamio/features/notifications/data/notification_service.dart';
import 'package:roamio/features/profile/data/firebase_privacy_service.dart';
import 'package:roamio/features/profile/data/privacy_service.dart';
import 'package:roamio/features/splits/ui/export_sheet.dart';
import 'package:roamio/features/squad/data/firebase_squad_service.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/sync/sync_controller.dart';
import 'package:roamio/features/tabs/data/firebase_tab_service.dart';
import 'package:roamio/features/tabs/data/payment_memory.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/updates/update_checker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() => runRoamio();

/// Starts the app. The journey tests (`integration_test/`) call this again
/// for each journey, swapping in a scripted connection and share sheet;
/// everything else is the real app against the Firebase emulators.
@visibleForTesting
Future<void> runRoamio({
  ConnectivityMonitor? connectivity,
  Future<void> Function(String text)? shareText,
  Future<void> Function(List<XFile> files, List<String> names)? shareFiles,
  bool phase2 = false,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final (:pipeline, :flush) = await (_started ??= _start());
  runApp(
    ProviderScope(
      overrides: [
        // Journey E still exercises the Phase 2 under-18 features.
        if (phase2) ...[
          minorsEnabledProvider.overrideWithValue(true),
          nomineeEnabledProvider.overrideWithValue(true),
        ],
        if (!firebaseUsesEmulators)
          crashReporterProvider.overrideWithValue(
            const FirebaseCrashReporter(),
          ),
        photoPipelineProvider.overrideWithValue(pipeline),
        photoFlushProvider.overrideWithValue(flush),
        connectivityMonitorProvider.overrideWithValue(
          connectivity ?? DeviceConnectivityMonitor(),
        ),
        networkSwitchProvider.overrideWithValue(
          FirestoreNetworkSwitch(FirebaseFirestore.instance),
        ),
        authServiceProvider.overrideWithValue(
          FirebaseAuthService(
            FirebaseAuth.instance,
            FirebaseFirestore.instance,
            GoogleSignIn.instance,
          ),
        ),
        adventureServiceProvider.overrideWithValue(
          FirebaseAdventureService(
            FirebaseAuth.instance,
            FirebaseFirestore.instance,
          ),
        ),
        bannerServiceProvider.overrideWithValue(
          FirebaseBannerService(FirebaseFirestore.instance, roamioFunctions),
        ),
        openLinkProvider.overrideWithValue(
          (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
        ),
        inviteServiceProvider.overrideWithValue(
          FirebaseInviteService(
            FirebaseAuth.instance,
            FirebaseFirestore.instance,
            roamioFunctions,
          ),
        ),
        paymentMemoryProvider.overrideWithValue(FilePaymentMemory()),
        homeCardMemoryProvider.overrideWithValue(FileHomeCardMemory()),
        updateCheckerProvider.overrideWithValue(
          UpdateChecker(fetchJsonOverHttp, FileUpdateStore()),
        ),
        remoteConfigSourceProvider.overrideWithValue(
          FirebaseRemoteConfigSource(FirebaseRemoteConfig.instance),
        ),
        privacyServiceProvider.overrideWithValue(
          FirebasePrivacyService(roamioFunctions),
        ),
        activityServiceProvider.overrideWithValue(
          FirebaseActivityService(FirebaseFirestore.instance),
        ),
        squadServiceProvider.overrideWithValue(
          FirebaseSquadService(
            FirebaseAuth.instance,
            FirebaseFirestore.instance,
            roamioFunctions,
          ),
        ),
        tabServiceProvider.overrideWithValue(
          FirebaseTabService(FirebaseAuth.instance, FirebaseFirestore.instance),
        ),
        notificationServiceProvider.overrideWithValue(
          FirebaseNotificationService(
            FirebaseAuth.instance,
            FirebaseFirestore.instance,
            FirebaseMessaging.instance,
          ),
        ),
        shareFilesProvider.overrideWithValue(
          shareFiles ??
              (files, names) => SharePlus.instance.share(
                ShareParams(files: files, fileNameOverrides: names),
              ),
        ),
        shareTextProvider.overrideWithValue(
          shareText ??
              (text) => SharePlus.instance.share(ShareParams(text: text)),
        ),
        consentServiceProvider.overrideWithValue(
          FirebaseConsentService(
            FirebaseAuth.instance,
            FirebaseFirestore.instance,
            roamioFunctions,
          ),
        ),
      ],
      child: const RoamioApp(),
    ),
  );
}

typedef _Started = ({PhotoPipeline pipeline, Future<void> Function() flush});

Future<_Started>? _started;

/// Firebase and the photo queue start once per process, however many times
/// [runRoamio] runs.
Future<_Started> _start() async {
  await setUpFirebase();
  return await startPhotoPipeline(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
    FirebaseAuth.instance.authStateChanges().map((user) => user?.uid),
  );
}

class RoamioApp extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<RoamioApp> createState() => _RoamioAppState();
}

class _RoamioAppState extends ConsumerState<RoamioApp> {
  final ValueNotifier<SessionStage> _stage = ValueNotifier(
    SessionStage.loading,
  );
  late final GoRouter _router = buildRouter(_stage);

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      sessionStageProvider,
      (_, next) => _stage.value = next.value ?? SessionStage.loading,
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _stage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(crashCollectionProvider);
    return MaterialApp.router(
      title: 'Roamio',
      theme: buildRoamioTheme(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => TodayRefresher(
        child: currentFlavor == Flavor.dev
            ? Banner(
                message: 'DEV',
                location: BannerLocation.topEnd,
                child: child,
              )
            : child!,
      ),
    );
  }
}
