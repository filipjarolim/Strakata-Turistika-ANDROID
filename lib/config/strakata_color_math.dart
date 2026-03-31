import 'package:flutter/material.dart';

/// HSL values as in CSS: hue 0–360, saturation/lightness 0–100%.
Color strakataHsl(double hue, double saturationPercent, double lightnessPercent) {
  return HSLColor.fromAHSL(
    1.0,
    hue.clamp(0.0, 360.0),
    (saturationPercent / 100.0).clamp(0.0, 1.0),
    (lightnessPercent / 100.0).clamp(0.0, 1.0),
  ).toColor();
}
