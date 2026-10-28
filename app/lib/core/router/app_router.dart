import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/ui/bottom_bar.dart';
import 'package:roamio/core/ui/placeholder_screen.dart';

abstract final class Routes {
  static const home = '/home';
  static const split = '/split';
  static const you = '/you';
}

const _tabs = [
  BottomBarItem(icon: Icons.explore_outlined, label: 'Home'),
  BottomBarItem(icon: Icons.pie_chart_outline, label: 'Split'),
  BottomBarItem(icon: Icons.sentiment_satisfied_alt_outlined, label: 'You'),
];

GoRouter buildRouter() => GoRouter(
  initialLocation: Routes.home,
  routes: [
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
