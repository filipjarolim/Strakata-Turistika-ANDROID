import 'package:flutter/material.dart';

class AppAnimations {
  // Durations — snappy active motion (aligned with StrakataMotion)
  static const Duration durationPress = Duration(milliseconds: 90);
  static const Duration durationShort = Duration(milliseconds: 160);
  static const Duration durationStandard = Duration(milliseconds: 240);
  static const Duration durationMedium = Duration(milliseconds: 240);
  static const Duration durationLong = Duration(milliseconds: 400);
  static const Duration durationPageTransition = Duration(milliseconds: 320);
  static const Duration durationHeroFade = Duration(milliseconds: 480);
  static const Duration durationLoaderPulse = Duration(milliseconds: 900);
  static const Duration durationGpsPulse = Duration(milliseconds: 1400);

  /// cubic-bezier(0.4, 0, 0.2, 1) — Material standard
  static const Cubic curveStandard = Cubic(0.4, 0.0, 0.2, 1.0);
  static const Cubic curveEmphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  // Curves
  static const Curve curveDecelerate = Curves.easeOutCubic;
  static const Curve curveAccelerate = Curves.easeInQuad;
  static const Curve curveBounce = Curves.easeOutBack;
  static const Curve curveSpring = Curves.easeOutBack;

  // Defaults
  static const Duration defaultDuration = durationStandard;
  static const Curve defaultCurve = curveStandard;
}
