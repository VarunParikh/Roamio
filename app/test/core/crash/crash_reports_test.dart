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

    test('leaves reports alone until it knows who this is', () async {
      // Switching off here would delete a crash waiting to upload from the
      // last run, when an adult was using the app.
      final reporter = _Recording();
      final container = ProviderContainer(
        overrides: [
          crashReporterProvider.overrideWithValue(reporter),
          sessionFactsProvider.overrideWith(
            (ref) => Stream.value(const SessionFacts.loading()),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(crashCollectionProvider, (_, _) {});
      await container.read(sessionFactsProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(reporter.enabled, isNull);
    });

    test('signing out switches reports off', () async {
      final reporter = _Recording();
      final container = ProviderContainer(
        overrides: [
          crashReporterProvider.overrideWithValue(reporter),
          sessionFactsProvider.overrideWith(
            (ref) => Stream.value(const SessionFacts.signedOut()),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(crashCollectionProvider, (_, _) {});
      await container.read(sessionFactsProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(reporter.enabled, isFalse);
    });

    test('a confirmed adult switches reports on', () async {
      final reporter = _Recording();
      final container = ProviderContainer(
        overrides: [
          crashReporterProvider.overrideWithValue(reporter),
          sessionFactsProvider.overrideWith(
            (ref) => Stream.value(
              const SessionFacts(uid: 'ari', ageStatus: 'adult'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(crashCollectionProvider, (_, _) {});
      await container.read(sessionFactsProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(reporter.enabled, isTrue);
    });

    group('what gets sent', () {
      late List<(Object, bool)> sent;
      late CrashLog log;

      setUp(() {
        sent = [];
        log = CrashLog(
          send: (error, stack, {required fatal}) async {
            sent.add((error, fatal));
          },
        );
      });

      test('nothing while reports are off', () {
        log
          ..error(Exception('boom'), StackTrace.empty)
          ..refusedWrite();
        expect(sent, isEmpty);
      });

      test('a refused write, without saying whose or what', () {
        log
          ..on = true
          ..refusedWrite();
        final (error, fatal) = sent.single;
        expect(fatal, isFalse);
        expect('$error', 'Server refused a queued write');
      });

      test('an uncaught error is fatal', () {
        log
          ..on = true
          ..error(Exception('boom'), StackTrace.empty);
        expect(sent.single.$2, isTrue);
      });
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
      await Future<void>.delayed(Duration.zero);
      expect(reporter.enabled, isFalse);
    });
  });
}
