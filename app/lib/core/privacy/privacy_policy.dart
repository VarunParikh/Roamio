import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/features/auth/data/auth_service.dart';

/// What the signed-in person's age allows (spec §7.2, CLAUDE.md). Every
/// feature that tracks, reports or locates must check this first.
class PrivacyPolicy {
  const new({required this.isMinor});

  /// Anyone not confirmed as an adult is treated as a minor, so a new or
  /// unknown status can never switch protections off.
  factory forAgeStatus(String? ageStatus) =>
      PrivacyPolicy(isMinor: ageStatus != 'adult');

  final bool isMinor;

  bool get allowsLocation => !isMinor;
  bool get allowsAnalytics => !isMinor;
  bool get allowsCrashReports => !isMinor;
}

final privacyPolicyProvider = Provider<PrivacyPolicy>(
  (ref) => PrivacyPolicy.forAgeStatus(
    ref.watch(sessionFactsProvider).value?.ageStatus,
  ),
);
