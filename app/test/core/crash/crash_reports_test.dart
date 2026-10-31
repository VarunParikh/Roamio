import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/crash/crash_reporter.dart';
import 'package:roamio/core/privacy/privacy_policy.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/session.dart';

class _Recording implements CrashReporter {
  bool? enabled;

  @override
  void setEnabled({required bool on}) => enabled = on;
}

void main() {
  group('crash reports (item 23, privacy: under-18 accounts)', () {
    test('only a confirmed adult gets crash reports', () {
      expect(PrivacyPolicy.forAgeStatus('adult').allowsCrashReports, isTrue);
      expect(PrivacyPolicy.forAgeStatus('minor').allowsCrashReports, isFalse);
      expect(PrivacyPolicy.forAgeStatus(null).allowsCrashReports, isFalse);
    });

    test('the reporter follows the signed-in person’s age', () async {
      final reporter = _Recording();
      final container = ProviderContainer(
        overrides: [
          crashReporterProvider.overrideWithValue(reporter),
          sessionFactsProvider.overrideWith(
            (ref) => Stream.value(
              const SessionFacts(uid: 'bea', ageStatus: 'minor'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(crashCollectionProvider, (_, _) {});
      await container.read(sessionFactsProvider.future);
      expect(reporter.enabled, isFalse);
    });
  });
}
