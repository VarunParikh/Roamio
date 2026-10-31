import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/banners/ui/banner_preloader.dart';

final _trip = Adventure(
  id: 'goa',
  name: 'Goa',
  countryCode: 'IN',
  startDate: DateTime(2099, 12),
  endDate: DateTime(2099, 12, 8),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari'],
  bannerUrl: 'https://images.example/goa.jpg',
);

void main() {
  testWidgets('saving an image that can’t load reports the failure (item 15)', (
    tester,
  ) async {
    final reported = <FlutterErrorDetails>[];
    final before = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = before);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));

    final outcome = await tester.runAsync(() async {
      try {
        await saveImage(MemoryImage(Uint8List.fromList([0, 1, 2])), context);
        return 'saved';
      } on Object {
        return 'failed';
      }
    });

    expect(outcome, 'failed');
    expect(reported, isEmpty, reason: 'a failed banner isn’t an app error');
  });

  testWidgets('a banner that fails to save is tried again later (item 15)', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myAdventuresProvider.overrideWith((ref) => Stream.value([_trip])),
          saveBannerProvider.overrideWithValue((context, url) async {
            attempts++;
            if (attempts == 1) throw Exception('network dropped');
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: BannerPreloader())),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(attempts, 1);

    // Not straight away, so a dead connection doesn't spin.
    await tester.pump(const Duration(minutes: 4));
    expect(attempts, 1);

    await tester.pump(const Duration(minutes: 2));
    await tester.pump();
    expect(attempts, 2);

    // Saved now, so it isn't saved again.
    await tester.pump(const Duration(minutes: 30));
    expect(attempts, 2);
  });
}
