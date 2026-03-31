import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'strakata_color_math.dart';

/// Decorative gradients (hero bands, chips, dividers)—not for body text.
class StrakataGradients {
  StrakataGradients._();

  static const brownStart = Color(0xFFF9DBC4);
  static const brownEnd = Color(0xFFDB7B2E);

  static const greenStart = Color(0xFFC4F9E0);
  static const greenEnd = Color(0xFF2EDB65);

  static const yellowLimeStart = Color(0xFFF2F9C4);
  static const yellowLimeEnd = Color(0xFFB6DB2E);

  static LinearGradient linearBrown({AlignmentGeometry begin = Alignment.centerLeft, AlignmentGeometry end = Alignment.centerRight}) {
    return LinearGradient(begin: begin, end: end, colors: const [brownStart, brownEnd]);
  }

  static LinearGradient linearGreen({AlignmentGeometry begin = Alignment.centerLeft, AlignmentGeometry end = Alignment.centerRight}) {
    return LinearGradient(begin: begin, end: end, colors: const [greenStart, greenEnd]);
  }

  static LinearGradient linearYellowLime({AlignmentGeometry begin = Alignment.centerLeft, AlignmentGeometry end = Alignment.centerRight}) {
    return LinearGradient(begin: begin, end: end, colors: const [yellowLimeStart, yellowLimeEnd]);
  }
}

/// Layout: max content width (web cap), section rhythm on large widths.
class StrakataLayout {
  StrakataLayout._();

  static const double maxContentWidth = 1920;

  /// Vertical/horizontal gaps in main shells (web ~35px; Flutter 32–36dp).
  static const double sectionGapWide = 36;

  /// Default horizontal inset for main tab scroll content and titles (dp).
  static const double pageHorizontalInset = 28;

  /// Extra top padding for primary scroll content under hero / app bars (dp).
  static const double pageContentTopInset = 44;

  /// `siteShellPadding`-style horizontal padding by breakpoint width (dp).
  static EdgeInsets shellPaddingForWidth(double width) {
    if (width >= 1536) return const EdgeInsets.symmetric(horizontal: 48);
    if (width >= 1280) return const EdgeInsets.symmetric(horizontal: 40);
    if (width >= 1024) return const EdgeInsets.symmetric(horizontal: 36);
    if (width >= 768) return const EdgeInsets.symmetric(horizontal: 32);
    if (width >= 640) return const EdgeInsets.symmetric(horizontal: 20);
    return const EdgeInsets.symmetric(horizontal: 16);
  }
}

/// Shape: large app rounding, component radii (sm/md/lg vs base ~10dp).
class StrakataRadii {
  StrakataRadii._();

  static const double app = 20;
  static const double base = 10;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
}

/// Motion: short 200ms, standard 300ms, Material-standard curve.
class StrakataMotion {
  StrakataMotion._();

  static const Duration short = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 300);
  static const Duration heroFade = Duration(milliseconds: 800);
  static const Duration sheetOrList = Duration(milliseconds: 500);

  /// cubic-bezier(0.4, 0, 0.2, 1)
  static const Cubic curveStandard = Cubic(0.4, 0.0, 0.2, 1.0);
}

/// Extended tokens for widgets that need web parity beyond [ColorScheme].
@immutable
class StrakataThemeExtension extends ThemeExtension<StrakataThemeExtension> {
  // ignore: prefer_const_constructors_in_immutables — HSL-derived colors are not const.
  StrakataThemeExtension({
    required this.heroOverlayTop,
    required this.brandMuted,
    required this.brandSubtle,
    required this.focusRing,
    required this.gradientBrown,
    required this.gradientGreen,
    required this.gradientYellowLime,
    required this.radiusApp,
    required this.radiusBase,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.sectionGapWide,
    required this.maxContentWidth,
  });

  final Color heroOverlayTop;
  final Color brandMuted;
  final Color brandSubtle;
  final Color focusRing;
  final List<Color> gradientBrown;
  final List<Color> gradientGreen;
  final List<Color> gradientYellowLime;
  final double radiusApp;
  final double radiusBase;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double sectionGapWide;
  final double maxContentWidth;

  static final StrakataThemeExtension light = StrakataThemeExtension(
    heroOverlayTop: const Color(0xFFF2F9C4),
    brandMuted: strakataHsl(152, 76, 88),
    brandSubtle: strakataHsl(72, 62, 90),
    focusRing: strakataHsl(142, 72, 40),
    gradientBrown: [StrakataGradients.brownStart, StrakataGradients.brownEnd],
    gradientGreen: [StrakataGradients.greenStart, StrakataGradients.greenEnd],
    gradientYellowLime: [StrakataGradients.yellowLimeStart, StrakataGradients.yellowLimeEnd],
    radiusApp: StrakataRadii.app,
    radiusBase: StrakataRadii.base,
    radiusSm: StrakataRadii.sm,
    radiusMd: StrakataRadii.md,
    radiusLg: StrakataRadii.lg,
    sectionGapWide: StrakataLayout.sectionGapWide,
    maxContentWidth: StrakataLayout.maxContentWidth,
  );

  @override
  StrakataThemeExtension copyWith({
    Color? heroOverlayTop,
    Color? brandMuted,
    Color? brandSubtle,
    Color? focusRing,
    List<Color>? gradientBrown,
    List<Color>? gradientGreen,
    List<Color>? gradientYellowLime,
    double? radiusApp,
    double? radiusBase,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? sectionGapWide,
    double? maxContentWidth,
  }) {
    return StrakataThemeExtension(
      heroOverlayTop: heroOverlayTop ?? this.heroOverlayTop,
      brandMuted: brandMuted ?? this.brandMuted,
      brandSubtle: brandSubtle ?? this.brandSubtle,
      focusRing: focusRing ?? this.focusRing,
      gradientBrown: gradientBrown ?? this.gradientBrown,
      gradientGreen: gradientGreen ?? this.gradientGreen,
      gradientYellowLime: gradientYellowLime ?? this.gradientYellowLime,
      radiusApp: radiusApp ?? this.radiusApp,
      radiusBase: radiusBase ?? this.radiusBase,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      sectionGapWide: sectionGapWide ?? this.sectionGapWide,
      maxContentWidth: maxContentWidth ?? this.maxContentWidth,
    );
  }

  @override
  StrakataThemeExtension lerp(ThemeExtension<StrakataThemeExtension>? other, double t) {
    if (other is! StrakataThemeExtension) return this;
    List<Color> lerpList(List<Color> a, List<Color> b) {
      final n = a.length;
      if (b.length != n) return t < 0.5 ? a : b;
      return List<Color>.generate(n, (i) => Color.lerp(a[i], b[i], t)!);
    }

    return StrakataThemeExtension(
      heroOverlayTop: Color.lerp(heroOverlayTop, other.heroOverlayTop, t)!,
      brandMuted: Color.lerp(brandMuted, other.brandMuted, t)!,
      brandSubtle: Color.lerp(brandSubtle, other.brandSubtle, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      gradientBrown: lerpList(gradientBrown, other.gradientBrown),
      gradientGreen: lerpList(gradientGreen, other.gradientGreen),
      gradientYellowLime: lerpList(gradientYellowLime, other.gradientYellowLime),
      radiusApp: lerpDouble(radiusApp, other.radiusApp, t)!,
      radiusBase: lerpDouble(radiusBase, other.radiusBase, t)!,
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t)!,
      sectionGapWide: lerpDouble(sectionGapWide, other.sectionGapWide, t)!,
      maxContentWidth: lerpDouble(maxContentWidth, other.maxContentWidth, t)!,
    );
  }
}

extension StrakataThemeExtensionContext on BuildContext {
  StrakataThemeExtension? get strakataTokens => Theme.of(this).extension<StrakataThemeExtension>();
}
