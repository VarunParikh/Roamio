import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/privacy/privacy_policy.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/session.dart';

import '../../support/fake_auth_service.dart';

void main() {
  group('PrivacyPolicy.forAgeStatus (spec §7.2)', () {
    test('adults may use location, analytics and crash reports', () {
      final p = PrivacyPolicy.forAgeStatus('adult');
      expect(p.allowsLocation, isTrue);
      expect(p.allowsAnalytics, isTrue);
      expect(p.allowsCrashReports, isTrue);
    });

    test('everything else is treated as a minor, including unknown', () {
      for (final status in [
        'minor_active',
        'minor_pending',
        'minor_frozen',
        'adult_unconfirmed',
        null,
        'something-new',
      ]) {
        final p = PrivacyPolicy.forAgeStatus(status);
        expect(p.allowsLocation, isFalse, reason: '$status');
        expect(p.allowsAnalytics, isFalse, reason: '$status');
        expect(p.allowsCrashReports, isFalse, reason: '$status');
      }
    });
  });

  test('follows the signed-in person, and is strict while loading', () async {
    final auth = FakeAuthService(initial: readyFacts);
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);
    final policy = container.listen(privacyPolicyProvider, (_, _) {});

    expect(policy.read().isMinor, isTrue);
    await container.read(sessionFactsProvider.future);
    expect(policy.read().isMinor, isFalse);

    // Let the fake's stream start listening for changes before emitting.
    await Future<void>.delayed(Duration.zero);
    auth.emit(
      const SessionFacts(
        uid: 'mia',
        hasAccount: true,
        ageStatus: 'minor_active',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(policy.read().allowsLocation, isFalse);
  });
}
