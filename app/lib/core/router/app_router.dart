import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/ui/bottom_bar.dart';
import 'package:roamio/core/ui/placeholder_screen.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/auth/ui/complete_profile_screen.dart';
import 'package:roamio/features/auth/ui/consent_pending_screen.dart';
import 'package:roamio/features/auth/ui/create_account_screen.dart';
import 'package:roamio/features/auth/ui/email_sign_in_screen.dart';
import 'package:roamio/features/auth/ui/login_screen.dart';
import 'package:roamio/features/auth/ui/verify_email_screen.dart';
import 'package:roamio/features/splash/ui/splash_screen.dart';

abstract final class Routes {
  static const String home = AuthRoutes.home;
  static const split = '/split';
  static const you = '/you';
}

const _tabs = [
  BottomBarItem(icon: Icons.explore_outlined, label: 'Home'),
  BottomBarItem(icon: Icons.pie_chart_outline, label: 'Split'),
  BottomBarItem(icon: Icons.sentiment_satisfied_alt_outlined, label: 'You'),
];

/// Routes follow [stage]: whenever it changes, [redirectFor] decides where
/// the person belongs (spec UC-1).
GoRouter buildRouter(ValueNotifier<SessionStage> stage) => GoRouter(
  initialLocation: AuthRoutes.splash,
  refreshListenable: stage,
  redirect: (context, state) => redirectFor(stage.value, state.matchedLocation),
  routes: [
    GoRoute(path: AuthRoutes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(
      path: AuthRoutes.login,
      builder: (_, _) => const LoginScreen(),
      routes: [
        GoRoute(path: 'email', builder: (_, _) => const EmailSignInScreen()),
      ],
    ),
    GoRoute(
      path: AuthRoutes.signup,
      builder: (_, _) => const CreateAccountScreen(),
    ),
    GoRoute(
      path: AuthRoutes.verifyEmail,
      builder: (_, _) => const VerifyEmailScreen(),
    ),
    GoRoute(
      path: AuthRoutes.completeProfile,
      builder: (_, _) => const CompleteProfileScreen(),
    ),
    GoRoute(
      path: AuthRoutes.consentPending,
      builder: (_, _) => const ConsentPendingScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Scaffold(
        extendBody: true,
        body: shell,
        bottomNavigationBar: RoamioBottomBar(
          items: _tabs,
          currentIndex: shell.currentIndex,
          onSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
        ),
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.home,
              builder: (_, _) => const PlaceholderScreen(
                title: 'Hey there 👋',
                message: 'Your adventures will live here.',
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.split,
              builder: (_, _) => const PlaceholderScreen(
                title: 'Split',
                message: 'Who owes whom, without the awkward math.',
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.you,
              builder: (_, _) => const PlaceholderScreen(
                title: 'You',
                message: 'Your profile and privacy centre.',
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);
