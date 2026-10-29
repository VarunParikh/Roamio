import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/images/photo_pipeline.dart';

void main() {
  group('scaledSize (spec §10: longest side capped)', () {
    test('shrinks so the longest side is the cap, keeping the shape', () {
      expect(scaledSize(4000, 3000, 1600), (1600, 1200));
      expect(scaledSize(3000, 4000, 1600), (1200, 1600));
      expect(scaledSize(3000, 4000, 2048), (1536, 2048));
      expect(scaledSize(4032, 1960, 1600), (1600, 778));
    });

    test('never enlarges a small photo', () {
      expect(scaledSize(1200, 900, 1600), (1200, 900));
      expect(scaledSize(1600, 1600, 1600), (1600, 1600));
    });

    test('keeps at least one pixel on very thin images', () {
      expect(scaledSize(10000, 2, 1600), (1600, 1));
    });
  });
}
