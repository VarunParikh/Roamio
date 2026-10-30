import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/ui/bottom_bar.dart';
import 'package:roamio/features/adventures/ui/activity_screen.dart';
import 'package:roamio/features/adventures/ui/adventure_page.dart';
import 'package:roamio/features/adventures/ui/create_adventure_screen.dart';
import 'package:roamio/features/adventures/ui/edit_adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/auth/ui/account_paused_screen.dart';
import 'package:roamio/features/auth/ui/complete_profile_screen.dart';
import 'package:roamio/features/auth/ui/confirm_adult_screen.dart';
import 'package:roamio/features/auth/ui/consent_pending_screen.dart';
import 'package:roamio/features/auth/ui/create_account_screen.dart';
import 'package:roamio/features/auth/ui/email_sign_in_screen.dart';
import 'package:roamio/features/auth/ui/login_screen.dart';
import 'package:roamio/features/auth/ui/verify_email_screen.dart';
import 'package:roamio/features/consent/ui/parent_consent_screen.dart';
import 'package:roamio/features/home/ui/home_screen.dart';
import 'package:roamio/features/invites/ui/invite_link_screen.dart';
import 'package:roamio/features/profile/ui/privacy_centre.dart';
import 'package:roamio/features/profile/ui/you_screen.dart';
import 'package:roamio/features/splash/ui/splash_screen.dart';
import 'package:roamio/features/splits/ui/split_screen.dart';
import 'package:roamio/features/tabs/ui/add_tab_screen.dart';
import 'package:roamio/features/tabs/ui/tab_detail.dart';
import 'package:roamio/features/updates/update_gate.dart';

/// Query parameter naming the adventure the Split tab opens on.
const splitAdventureParam = 'adventure';

abstract final class Routes {
  static const String home = AuthRoutes.home;
  static const split = '/split';

  /// The Split tab opened on [adventureId] (spec UC-5, UC-20).
  static String splitFor(String adventureId) => Uri(
    path: split,
    queryParameters: {splitAdventureParam: adventureId},
  ).toString();
  static const you = '/you';
}

const _tabs = [
  BottomBarItem(icon: Icons.explore_outlined, label: 'Home'),
  BottomBarItem(icon: Icons.pie_chart_outline, label: 'Split'),
  BottomBarItem(icon: Icons.sentiment_satisfied_alt_outlined, label: 'You'),
];

/// Routes follow [stage]: whenever it changes, [resolveRoute] decides where
/// the person belongs (spec UC-1), keeping a deep link through sign-in.
GoRouter buildRouter(ValueNotifier<SessionStage> stage) {
  String? pending;
  return GoRouter(
    initialLocation: AuthRoutes.splash,
    refreshListenable: stage,
    redirect: (context, state) {
      final route = resolveRoute(stage.value, state.uri, pending: pending);
      pending = route.pending;
      return route.redirect;
    },
    routes: _routes,
  );
}

final _routes = <RouteBase>[
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
  GoRoute(
    path: AuthRoutes.accountPaused,
    builder: (_, _) => const AccountPausedScreen(),
  ),
  GoRoute(
    path: '/i/:code',
    builder: (_, state) =>
        InviteLinkScreen(code: state.pathParameters['code']!),
  ),
  GoRoute(
    path: '/adventures/new',
    builder: (_, _) => const CreateAdventureScreen(),
  ),
  GoRoute(
    path: '/adventures/:id',
    builder: (_, state) =>
        AdventurePage(adventureId: state.pathParameters['id']!),
    routes: [
      GoRoute(
        path: 'edit',
        builder: (_, state) =>
            EditAdventureScreen(adventureId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: 'activity',
        builder: (_, state) =>
            ActivityScreen(adventureId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: 'tabs/new',
        builder: (_, state) =>
            AddTabScreen(adventureId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: 'tabs/:tid',
        builder: (_, state) => TabDetailScreen(
          adventureId: state.pathParameters['id']!,
          tabId: state.pathParameters['tid']!,
        ),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) => AddTabScreen(
              adventureId: state.pathParameters['id']!,
              tabId: state.pathParameters['tid'],
            ),
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: AuthRoutes.confirmAdult,
    builder: (_, _) => const ConfirmAdultScreen(),
  ),
  GoRoute(
    path: AuthRoutes.consent,
    builder: (_, state) => ParentConsentScreen(
      childUid: state.uri.queryParameters['c'] ?? '',
      token: state.uri.queryParameters['t'] ?? '',
    ),
  ),
  GoRoute(
    path: privacyCentreRoute,
    builder: (_, _) => const PrivacyCentreScreen(),
  ),
  StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => UpdateGate(
      child: Scaffold(
        extendBody: true,
        body: shell,
        bottomNavigationBar: RoamioBottomBar(
          items: _tabs,
          currentIndex: shell.currentIndex,
          onSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
        ),
      ),
    ),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.split,
            builder: (_, state) => SplitScreen(
              adventureId: state.uri.queryParameters[splitAdventureParam],
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(path: Routes.you, builder: (_, _) => const YouScreen()),
        ],
      ),
    ],
  ),
];
