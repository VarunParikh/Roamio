import 'package:flutter/painting.dart';

/// Colour tokens from `design/DESIGN.md`.
abstract final class RoamioColors {
  static const canvas = Color(0xFFF9FAFB);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0F1115);
  static const cobalt = Color(0xFF2563EB);
  static const chartreuse = Color(0xFFD4FF00);
  static const coral = Color(0xFFF43F5E);
  static const mint = Color(0xFF10B981);
  static const slate = Color(0xFF64748B);
  static const muted = Color(0xFFA1A1AA);

  /// Coral and mint are too light for text on canvas or white (3.5:1 and
  /// 2.5:1); these darker shades of the same hues pass 4.5:1 (spec §12).
  /// Use them for words, and coral/mint for fills, bars and icons.
  static const coralText = Color(0xFFBE123C);
  static const mintText = Color(0xFF047857);
  static const hairline = Color(0xFFE4E4E7);
  static const pressed = Color(0xFFF4F4F5);
}

/// Corner radii from `design/DESIGN.md`.
abstract final class RoamioRadii {
  static const sm = 8.0;
  static const base = 16.0;
  static const md = 24.0;
  static const lg = 32.0;
  static const xl = 48.0;
  static const full = 9999.0;
}
