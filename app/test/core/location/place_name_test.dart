import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/core/location/place_text.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/session.dart';

const _bangkok = MapPoint(13.7563, 100.5018);

class _Names implements PlaceNames {
  new(this.answer);

  final String? answer;
  int asked = 0;

  @override
  Future<String?> nameOf(MapPoint point) async {
    asked++;
    return answer;
  }
}

Future<void> _pump(WidgetTester tester, _Names names, String ageStatus) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeNamesProvider.overrideWithValue(names),
          sessionFactsProvider.overrideWith(
            (ref) =>
                Stream.value(SessionFacts(uid: 'ari', ageStatus: ageStatus)),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PlaceText(point: _bangkok)),
        ),
      ),
    );

void main() {
  group('placeName', () {
    test('the town and country', () {
      expect(
        placeName(locality: 'Bangkok', area: 'Krung Thep', country: 'Thailand'),
        'Bangkok, Thailand',
      );
    });

    test('the wider area when there is no town', () {
      expect(
        placeName(area: 'Phuket', country: 'Thailand'),
        'Phuket, Thailand',
      );
    });

    test('whatever it has, and nothing when it has nothing', () {
      expect(placeName(locality: 'Bangkok', country: ' '), 'Bangkok');
      expect(placeName(locality: ''), isNull);
    });
  });

  group('PlaceText', () {
    testWidgets('shows the place name once it’s known', (tester) async {
      await _pump(tester, _Names('Bangkok, Thailand'), 'adult');
      await tester.pumpAndSettle();
      expect(find.text('📍 Bangkok, Thailand'), findsOneWidget);
    });

    testWidgets('shows the coordinates until then, or with no name', (
      tester,
    ) async {
      await _pump(tester, _Names(null), 'adult');
      expect(find.text('📍 13.7563, 100.5018'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('📍 13.7563, 100.5018'), findsOneWidget);
    });

    testWidgets('an under-18 account never sends a location to be looked up', (
      tester,
    ) async {
      final names = _Names('Bangkok, Thailand');
      await _pump(tester, names, 'minor_active');
      await tester.pumpAndSettle();
      expect(names.asked, 0);
      expect(find.text('📍 13.7563, 100.5018'), findsOneWidget);
    });

    testWidgets('someone whose age isn’t known yet doesn’t either', (
      tester,
    ) async {
      final names = _Names('Bangkok, Thailand');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            placeNamesProvider.overrideWithValue(names),
            sessionFactsProvider.overrideWith(
              (ref) => Stream.value(const SessionFacts.loading()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: PlaceText(point: _bangkok)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(names.asked, 0);
    });

    testWidgets('one place is only looked up once', (tester) async {
      final names = _Names('Bangkok, Thailand');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            placeNamesProvider.overrideWithValue(names),
            sessionFactsProvider.overrideWith(
              (ref) => Stream.value(
                const SessionFacts(uid: 'ari', ageStatus: 'adult'),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  PlaceText(point: _bangkok),
                  PlaceText(point: _bangkok),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(names.asked, 1);
    });
  });
}
