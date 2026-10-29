import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:roamio/core/config/flavor.dart';
import 'package:roamio/core/firebase/firebase_setup.dart';
import 'package:roamio/core/router/app_router.dart';
import 'package:roamio/core/theme/roamio_theme.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/data/firebase_adventure_service.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/data/firebase_auth_service.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/consent/data/consent_service.dart';
import 'package:roamio/features/consent/data/firebase_consent_service.dart';
import 'package:roamio/features/invites/data/firebase_invite_service.dart';
import 'package:roamio/features/invites/data/invite_service.dart';
import 'package:roamio/features/invites/ui/invite_section.dart';
import 'package:share_plus/share_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setUpFirebase();
  runApp(
    ProviderScope(
      overrides: [
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
        inviteServiceProvider.overrideWithValue(
          FirebaseInviteService(
            FirebaseAuth.instance,
            FirebaseFirestore.instance,
            roamioFunctions,
          ),
        ),
        shareTextProvider.overrideWithValue(
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
    return MaterialApp.router(
      title: 'Roamio',
      theme: buildRoamioTheme(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => currentFlavor == Flavor.dev
          ? Banner(
              message: 'DEV',
              location: BannerLocation.topEnd,
              child: child,
            )
          : child!,
    );
  }
}
