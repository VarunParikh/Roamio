import 'package:flutter/services.dart';

enum Flavor { dev, prod }

/// The build flavor, from `flutter run --flavor <dev|prod>`.
/// Builds without a flavor (tests, plain `flutter run`) count as dev.
Flavor get currentFlavor => appFlavor == 'prod' ? Flavor.prod : Flavor.dev;
