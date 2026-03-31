import 'package:flutter/material.dart';

class AppAnimations {
  // Durations (web-aligned: short 200ms, standard 300ms)
  static const Duration durationShort = Duration(milliseconds: 200);
  static const Duration durationStandard = Duration(milliseconds: 300);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationLong = Duration(milliseconds: 600);
  static const Duration durationPageTransition = Duration(milliseconds: 500);
  static const Duration durationHeroFade = Duration(milliseconds: 800);

  /// cubic-bezier(0.4, 0, 0.2, 1) — Material standard
  static const Cubic curveStandard = Cubic(0.4, 0.0, 0.2, 1.0);

  // Curves
  static const Curve curveDecelerate = Curves.easeOutQuart;
  static const Curve curveAccelerate = Curves.easeInQuad;
  static const Curve curveBounce = Curves.elasticOut;
  static const Curve curveSpring = Curves.elasticOut;

  // Defaults
  static const Duration defaultDuration = durationStandard;
  static const Curve defaultCurve = curveStandard;
}
