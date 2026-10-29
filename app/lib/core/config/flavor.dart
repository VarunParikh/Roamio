import 'package:flutter/services.dart';

enum Flavor { dev, prod }

/// The build flavor, from `flutter run --flavor <dev|prod>`.
/// Builds without a flavor (tests, plain `flutter run`) count as dev.
Flavor get currentFlavor => appFlavor == 'prod' ? Flavor.prod : Flavor.dev;

/// The Firebase Hosting site for links people open outside the app
/// (invites, parental consent).
String get siteUrl => currentFlavor == Flavor.prod
    ? 'https://roamio-prod-varun.web.app'
    : 'https://roamio-dev-varun.web.app';
