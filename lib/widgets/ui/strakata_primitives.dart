// Strakatá shared UI primitives (main app shell).
//
// Use for: modal sheet shape/handle, white elevated cards, section/sheet titles.
// Admin screens may use `admin_theme.dart` / `admin_page_template.dart` instead.
import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/strakata_design_tokens.dart';

/// Top radius and [ShapeBorder] for standard app bottom sheets (non-admin).
abstract final class StrakataSheetTheme {
  static const double topRadius = 24;

  static const ShapeBorder shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
  );
}

/// Drag handle shown at the top of modal bottom sheets.
class StrakataSheetHandle extends StatelessWidget {
  const StrakataSheetHandle({
    super.key,
    this.color,
    this.margin = EdgeInsets.zero,
    this.width = 40,
    this.height = 4,
    this.borderRadius = 2,
  });

  /// Default matches common sheets (gray-200).
  static const Color defaultColor = Color(0xFFE5E7EB);

  final Color? color;
  final EdgeInsetsGeometry margin;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? defaultColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Standard white “card” surface used across profile, explore-style lists, etc.
abstract final class StrakataSurface {
  StrakataSurface._();

  static BoxDecoration cardDecoration({
    Color color = Colors.white,
    double borderRadius = StrakataRadii.app,
    Color? borderColor,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: boxShadow ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
      border: Border.all(color: borderColor ?? AppColors.divider),
    );
  }
}

/// White rounded container with [StrakataSurface.cardDecoration].
class StrakataSurfaceCard extends StatelessWidget {
  const StrakataSurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.clipBehavior = Clip.antiAlias,
    this.decoration,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final Clip clipBehavior;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      clipBehavior: clipBehavior,
      padding: padding,
      decoration: decoration ?? StrakataSurface.cardDecoration(),
      child: child,
    );
  }
}

/// Primary section heading on main app screens (e.g. “Moje Trasy”).
class StrakataSectionTitle extends StatelessWidget {
  const StrakataSectionTitle(
    this.text, {
    super.key,
    this.fontSize = 20,
    this.color = const Color(0xFF111827),
    this.letterSpacing = -0.5,
  });

  final String text;
  final double fontSize;
  final Color color;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: letterSpacing,
      ),
    );
  }
}

/// Title line inside modal sheets (help, offline, edit profile, …).
class StrakataSheetTitle extends StatelessWidget {
  const StrakataSheetTitle(
    this.text, {
    super.key,
    this.fontSize = 20,
    this.fontWeight = FontWeight.w800,
  });

  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// Opinionated [showModalBottomSheet] for the default white top-rounded sheet.
/// Matches Flutter’s default `isScrollControlled: false` unless you set it.
Future<T?> showStrakataModalBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  bool isScrollControlled = false,
  Color backgroundColor = Colors.white,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor,
    shape: StrakataSheetTheme.shape,
    builder: builder,
  );
}
