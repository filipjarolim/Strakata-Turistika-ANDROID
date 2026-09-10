import 'package:flutter/material.dart';
import 'season_theme.dart';
import 'strakata_color_math.dart';

/// Strakatá turistika palette. Prefer [Theme.of(context).colorScheme]
/// in new UI; static getters track the active [SeasonPalette] for existing code.
class AppColors {
  AppColors._();

  static SeasonPalette _palette = SeasonPalette.forSeason(AppSeason.spring);

  /// Apply seasonal tokens so existing `AppColors.*` call sites update live.
  static void applyPalette(SeasonPalette palette) {
    _palette = palette;
  }

  static SeasonPalette get activePalette => _palette;

  // Page / canvas
  static Color get pageBg => _palette.pageBg;

  // Brand — seasonal (via applyPalette)
  static Color get brand => _palette.brand;
  static Color get brandForeground => Colors.white;

  /// Always-green primary CTA (Start tracking, success actions) — not seasonal.
  static Color get ctaGreen => strakataHsl(142, 72, 46);
  static Color get ctaGreenDark => strakataHsl(142, 72, 36);

  // Supporting surfaces
  static Color get brandMuted => _palette.brandMuted;
  static Color get brandSubtle => _palette.brandSubtle;

  // Semantic surfaces
  static Color get background => _palette.pageBg;
  static Color get surface => const Color(0xFFFFFFFF);
  static Color get surfaceMuted => _palette.surfaceMuted;
  static Color get surfaceVariant => _palette.surfaceVariant;

  // Text (stable across seasons for readability)
  static const Color textPrimary = Color(0xFF0A0A0A);
  static const Color textSecondary = Color(0xFF1A1A1A);
  static const Color textTertiary = Color(0xFF525252);

  // Borders
  static Color get border => _palette.border;
  static Color get divider => _palette.divider;

  // Destructive
  static Color get error => strakataHsl(0, 84.2, 60.2);
  static Color get errorContainer => strakataHsl(0, 84, 95);
  static Color get onErrorContainer => strakataHsl(0, 70, 30);

  // Semantic (non-error)
  static Color get success => _palette.success;
  static Color get warning => strakataHsl(38, 92, 50);
  static Color get info => strakataHsl(200, 80, 46);

  // Focus ring
  static Color get focusRing => _palette.focusRing;

  // Legacy names
  static Color get primary => brand;
  static Color get secondary => _palette.secondary;
  static Color get accent => brandMuted;

  static Color get overlay => const Color(0x66000000);
  static Color get shadow => const Color(0x1A000000);

  /// Hero overlay wash (pairs with decorative gradients).
  static Color get heroOverlayTop => _palette.heroOverlayTop;
}
