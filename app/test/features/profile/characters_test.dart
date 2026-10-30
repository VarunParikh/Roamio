import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/profile/domain/characters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the characters', () {
    test('there are 47, each with its own id and a name for TalkBack', () {
      expect(characters, hasLength(47));
      expect(characters.map((c) => c.id).toSet(), hasLength(47));
      for (final c in characters) {
        expect(c.label, isNotEmpty);
      }
    });

    test('ids fit what the security rules accept', () {
      final rule = RegExp(r'^[a-z0-9_]{1,30}$');
      for (final c in characters) {
        expect(rule.hasMatch(c.id), isTrue, reason: c.id);
      }
    });

    test('an id finds its character; an unknown one finds nothing', () {
      expect(characterById('panda')?.label, 'Panda');
      expect(characterById('not_a_character'), isNull);
      expect(characterById(null), isNull);
    });

    test('the images on disk are exactly the characters', () {
      final files = Directory('assets/characters')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(files, characters.map((c) => '${c.id}.webp').toSet());
    });

    testWidgets('every image is opaque, on a white background', (tester) async {
      await tester.runAsync(() async {
        for (final c in characters) {
          final bytes = await rootBundle.load(c.asset);
          final codec = await ui.instantiateImageCodec(
            bytes.buffer.asUint8List(),
          );
          final image = (await codec.getNextFrame()).image;
          final data = await image.toByteData();
          final pixels = data!.buffer.asUint8List();
          for (var i = 3; i < pixels.length; i += 4) {
            expect(pixels[i], 255, reason: '${c.id} has see-through pixels');
          }
          expect(image.width, image.height, reason: '${c.id} is not square');
          // The top-left corner is background: white, allowing for compression.
          expect(pixels.sublist(0, 3), everyElement(greaterThan(250)));
          image.dispose();
        }
      });
    });
  });
}
