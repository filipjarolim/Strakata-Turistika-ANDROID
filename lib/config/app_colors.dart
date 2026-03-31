import 'package:flutter/material.dart';
import 'strakata_color_math.dart';

/// Strakatá turistika palette (web parity). Prefer [Theme.of(context).colorScheme]
/// and [StrakataThemeExtension] in new UI; this class keeps stable names for existing imports.
class AppColors {
  AppColors._();

  // Page / canvas
  static const Color pageBg = Color(0xFFFAFAF6);

  // Brand — HSL 142 72% 46%
  static Color get brand => strakataHsl(142, 72, 46);
  static Color get brandForeground => Colors.white;

  // Supporting surfaces
  static Color get brandMuted => strakataHsl(152, 76, 88);
  static Color get brandSubtle => strakataHsl(72, 62, 90);

  // Semantic surfaces (warm gray family, web --background / --muted)
  static Color get background => strakataHsl(48, 35, 98);
  static Color get surface => const Color(0xFFFFFFFF);
  static Color get surfaceMuted => strakataHsl(48, 22, 94);
  static Color get surfaceVariant => strakataHsl(48, 28, 96);

  // Text
  static const Color textPrimary = Color(0xFF0A0A0A);
  static const Color textSecondary = Color(0xFF1A1A1A);
  static const Color textTertiary = Color(0xFF525252);

  // Borders
  static Color get border => strakataHsl(48, 18, 88);
  static Color get divider => strakataHsl(48, 16, 90);

  // Destructive — HSL ~0 84.2% 60.2%
  static Color get error => strakataHsl(0, 84.2, 60.2);
  static Color get errorContainer => strakataHsl(0, 84, 95);
  static Color get onErrorContainer => strakataHsl(0, 70, 30);

  // Semantic (non-error)
  static Color get success => strakataHsl(142, 72, 36);
  static Color get warning => strakataHsl(38, 92, 50);
  static Color get info => strakataHsl(200, 80, 46);

  // Focus ring — HSL 142 72% 40%
  static Color get focusRing => strakataHsl(142, 72, 40);

  // Legacy names (mapped to new system)
  static Color get primary => brand;
  static Color get secondary => strakataHsl(142, 55, 32);
  static Color get accent => brandMuted;

  static Color get overlay => const Color(0x66000000);
  static Color get shadow => const Color(0x1A000000);

  /// Hero overlay wash (pairs with decorative gradients).
  static const Color heroOverlayTop = Color(0xFFF2F9C4);
}
