import 'package:flutter/material.dart';
import 'strakata_color_math.dart';

/// Meteorologické roční období (CZ): březen–květen jaro, … září–listopad podzim.
enum AppSeason {
  spring,
  summer,
  autumn,
  winter;

  String get id {
    switch (this) {
      case AppSeason.spring:
        return 'spring';
      case AppSeason.summer:
        return 'summer';
      case AppSeason.autumn:
        return 'autumn';
      case AppSeason.winter:
        return 'winter';
    }
  }

  String get labelCs {
    switch (this) {
      case AppSeason.spring:
        return 'Jaro';
      case AppSeason.summer:
        return 'Léto';
      case AppSeason.autumn:
        return 'Podzim';
      case AppSeason.winter:
        return 'Zima';
    }
  }

  String get subtitleCs {
    switch (this) {
      case AppSeason.spring:
        return 'Svěží zelená, lehký start sezóny';
      case AppSeason.summer:
        return 'Slunečná a výrazná zelená';
      case AppSeason.autumn:
        return 'Teplé oranžovo-jantarové tóny';
      case AppSeason.winter:
        return 'Chladná borovicová a zimní paleta';
    }
  }

  IconData get icon {
    switch (this) {
      case AppSeason.spring:
        return Icons.local_florist_rounded;
      case AppSeason.summer:
        return Icons.wb_sunny_rounded;
      case AppSeason.autumn:
        return Icons.eco_rounded;
      case AppSeason.winter:
        return Icons.ac_unit_rounded;
    }
  }

  static AppSeason fromId(String? id) {
    return AppSeason.values.firstWhere(
      (s) => s.id == id,
      orElse: () => AppSeason.calendarDefault(),
    );
  }

  /// Výchozí podle kalendáře (meteorologické období).
  static AppSeason calendarDefault([DateTime? now]) {
    final m = (now ?? DateTime.now()).month;
    if (m >= 3 && m <= 5) return AppSeason.spring;
    if (m >= 6 && m <= 8) return AppSeason.summer;
    if (m >= 9 && m <= 11) return AppSeason.autumn;
    return AppSeason.winter;
  }
}

/// Launcher / home-screen icon variants.
enum AppIconVariant {
  classic,
  autumn;

  String get id => this == AppIconVariant.classic ? 'classic' : 'autumn';

  String get labelCs =>
      this == AppIconVariant.classic ? 'Klasická' : 'Podzimní';

  String get previewAsset => this == AppIconVariant.classic
      ? 'assets/icons/app_icon_classic.png'
      : 'assets/icons/app_icon_autumn_preview.png';

  /// iOS alternate icon name (`null` = primary).
  String? get iosAlternateName =>
      this == AppIconVariant.classic ? null : 'AppIconAutumn';

  /// Android component: real MainActivity (classic) or autumn activity-alias.
  String get androidAliasSuffix => this == AppIconVariant.classic
      ? 'MainActivity'
      : 'MainActivityAutumn';

  static AppIconVariant fromId(String? id) {
    if (id == 'autumn') return AppIconVariant.autumn;
    return AppIconVariant.classic;
  }
}

/// Light-mode color tokens for one season.
@immutable
class SeasonPalette {
  const SeasonPalette({
    required this.season,
    required this.brand,
    required this.brandMuted,
    required this.brandSubtle,
    required this.secondary,
    required this.focusRing,
    required this.pageBg,
    required this.surfaceMuted,
    required this.surfaceVariant,
    required this.border,
    required this.divider,
    required this.heroOverlayTop,
    required this.success,
    required this.gradientBrown,
    required this.gradientGreen,
    required this.gradientYellowLime,
  });

  final AppSeason season;
  final Color brand;
  final Color brandMuted;
  final Color brandSubtle;
  final Color secondary;
  final Color focusRing;
  final Color pageBg;
  final Color surfaceMuted;
  final Color surfaceVariant;
  final Color border;
  final Color divider;
  final Color heroOverlayTop;
  final Color success;
  final List<Color> gradientBrown;
  final List<Color> gradientGreen;
  final List<Color> gradientYellowLime;

  static SeasonPalette forSeason(AppSeason season) {
    switch (season) {
      case AppSeason.spring:
        return SeasonPalette(
          season: season,
          brand: strakataHsl(142, 72, 46),
          brandMuted: strakataHsl(152, 76, 88),
          brandSubtle: strakataHsl(72, 62, 90),
          secondary: strakataHsl(142, 55, 32),
          focusRing: strakataHsl(142, 72, 40),
          pageBg: const Color(0xFFFAFAF6),
          surfaceMuted: strakataHsl(48, 22, 94),
          surfaceVariant: strakataHsl(48, 28, 96),
          border: strakataHsl(48, 18, 88),
          divider: strakataHsl(48, 16, 90),
          heroOverlayTop: const Color(0xFFF2F9C4),
          success: strakataHsl(142, 72, 36),
          gradientBrown: const [Color(0xFFF9DBC4), Color(0xFFDB7B2E)],
          gradientGreen: const [Color(0xFFC4F9E0), Color(0xFF2EDB65)],
          gradientYellowLime: const [Color(0xFFF2F9C4), Color(0xFFB6DB2E)],
        );
      case AppSeason.summer:
        return SeasonPalette(
          season: season,
          brand: strakataHsl(145, 78, 40),
          brandMuted: strakataHsl(145, 70, 86),
          brandSubtle: strakataHsl(55, 85, 90),
          secondary: strakataHsl(145, 60, 28),
          focusRing: strakataHsl(145, 78, 34),
          pageBg: const Color(0xFFFFFDF5),
          surfaceMuted: strakataHsl(50, 40, 95),
          surfaceVariant: strakataHsl(50, 35, 97),
          border: strakataHsl(48, 22, 88),
          divider: strakataHsl(48, 18, 90),
          heroOverlayTop: const Color(0xFFFFF3A8),
          success: strakataHsl(145, 72, 32),
          gradientBrown: const [Color(0xFFFFE0B8), Color(0xFFF08A24)],
          gradientGreen: const [Color(0xFFB8F5D0), Color(0xFF1EC95A)],
          gradientYellowLime: const [Color(0xFFFFF6A8), Color(0xFFD4E012)],
        );
      case AppSeason.autumn:
        return SeasonPalette(
          season: season,
          brand: strakataHsl(28, 82, 48),
          brandMuted: strakataHsl(32, 70, 90),
          brandSubtle: strakataHsl(38, 55, 92),
          secondary: strakataHsl(18, 55, 34),
          focusRing: strakataHsl(28, 82, 42),
          pageBg: const Color(0xFFFFF8F1),
          surfaceMuted: strakataHsl(32, 28, 94),
          surfaceVariant: strakataHsl(32, 32, 96),
          border: strakataHsl(30, 22, 86),
          divider: strakataHsl(30, 18, 90),
          heroOverlayTop: const Color(0xFFFFE2C4),
          success: strakataHsl(120, 35, 36),
          gradientBrown: const [Color(0xFFF9DBC4), Color(0xFFC45A1A)],
          gradientGreen: const [Color(0xFFE8F0C8), Color(0xFF7A9B2E)],
          gradientYellowLime: const [Color(0xFFFFE8B0), Color(0xFFE0A020)],
        );
      case AppSeason.winter:
        return SeasonPalette(
          season: season,
          brand: strakataHsl(168, 42, 36),
          brandMuted: strakataHsl(175, 35, 88),
          brandSubtle: strakataHsl(200, 28, 92),
          secondary: strakataHsl(200, 35, 30),
          focusRing: strakataHsl(168, 42, 30),
          pageBg: const Color(0xFFF5F8FA),
          surfaceMuted: strakataHsl(200, 18, 94),
          surfaceVariant: strakataHsl(200, 22, 96),
          border: strakataHsl(200, 14, 86),
          divider: strakataHsl(200, 12, 90),
          heroOverlayTop: const Color(0xFFD9EEF2),
          success: strakataHsl(168, 40, 32),
          gradientBrown: const [Color(0xFFE8D5C8), Color(0xFF8B6A55)],
          gradientGreen: const [Color(0xFFC8EDE4), Color(0xFF2A8F78)],
          gradientYellowLime: const [Color(0xFFE0F0F5), Color(0xFF5BA3B8)],
        );
    }
  }
}
