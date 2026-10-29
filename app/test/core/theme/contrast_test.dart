import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/theme/roamio_colors.dart';

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  double lum(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final (hi, lo) = (max(lum(a), lum(b)), min(lum(a), lum(b)));
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('every colour used for text on the light surfaces reaches 4.5:1 '
      '(spec §12)', () {
    const text = {
      'ink': RoamioColors.ink,
      'slate': RoamioColors.slate,
      'cobalt': RoamioColors.cobalt,
      'coralText': RoamioColors.coralText,
      'mintText': RoamioColors.mintText,
    };
    for (final bg in [RoamioColors.canvas, RoamioColors.surface]) {
      for (final MapEntry(:key, :value) in text.entries) {
        expect(
          _contrast(value, bg),
          greaterThanOrEqualTo(4.5),
          reason: '$key on $bg',
        );
      }
    }
  });

  test('ink on chartreuse (the primary button) and white on ink pass', () {
    expect(
      _contrast(RoamioColors.ink, RoamioColors.chartreuse),
      greaterThan(4.5),
    );
    expect(_contrast(RoamioColors.surface, RoamioColors.ink), greaterThan(4.5));
  });
}
