import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/config/flavor.dart';
import 'package:roamio/core/router/app_router.dart';
import 'package:roamio/core/theme/roamio_theme.dart';

void main() {
  runApp(const ProviderScope(child: RoamioApp()));
}

class RoamioApp extends StatefulWidget {
  const new({super.key});

  @override
  State<RoamioApp> createState() => _RoamioAppState();
}

class _RoamioAppState extends State<RoamioApp> {
  late final GoRouter _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
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
