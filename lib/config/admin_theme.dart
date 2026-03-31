import 'package:flutter/material.dart';
import 'strakata_color_math.dart';

/// Admin-only workspace: mint / neutral shell, status yellow — separate from the main user chrome.
class AdminColors {
  // Workspace (mint + cool gray, web F0FFF4 / F9FAFB)
  static final workspaceMint = strakataHsl(142, 45, 97);
  static const workspaceNeutral = Color(0xFFF9FAFB);
  static const white = Color(0xFFFFFFFF);

  static const zinc100 = Color(0xFFF4F4F5);
  static const zinc200 = Color(0xFFE4E4E7);
  static const zinc300 = Color(0xFFD4D4D8);
  static const zinc400 = Color(0xFFA1A1AA);
  static const zinc500 = Color(0xFF71717A);
  static const zinc900 = Color(0xFF18181B);

  // Brand-aligned primary (review actions) — not default Material purple
  static final primary = strakataHsl(142, 72, 46);
  static final primaryMuted = strakataHsl(152, 76, 88);

  // Status yellow (alerts / pending)
  static const statusYellow = Color(0xFFFEF9C3);
  static const statusYellowForeground = Color(0xFF713F12);

  // Semantic
  static final success = strakataHsl(142, 72, 36);
  static const warning = Color(0xFFF59E0B);
  static final error = strakataHsl(0, 84.2, 60.2);

  // Surfaces for badges (const-friendly)
  static const emerald100 = Color(0xFFD1FAE5);
  static const rose100 = Color(0xFFFFE4E6);
  static const amber100 = Color(0xFFFEF9C3);

  // Legacy aliases (older admin widgets)
  static Color get zinc50 => workspaceMint;
  static Color get blue500 => primary;
  static Color get blue600 => strakataHsl(142, 72, 40);
  static Color get emerald500 => success;
  static Color get emerald600 => strakataHsl(142, 72, 32);
  static Color get amber500 => warning;
  static Color get amber600 => Color(0xFFD97706);
  static Color get rose500 => error;
  static Color get rose600 => strakataHsl(0, 84, 52);
  static Color get purple100 => primaryMuted;
  static Color get purple500 => strakataHsl(280, 60, 55);
  static Color get purple600 => strakataHsl(280, 60, 48);
  static Color get indigo500 => strakataHsl(220, 70, 50);
  static Color get indigo600 => strakataHsl(220, 70, 44);

  static Color glassLow = white.withValues(alpha: 0.4);
  static Color glassMedium = white.withValues(alpha: 0.6);
  static Color glassHigh = white.withValues(alpha: 0.8);
  static Color glassSubtle = workspaceMint.withValues(alpha: 0.5);
}

class AdminTextStyles {
  static const display = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    height: 1.0,
    letterSpacing: -0.5,
    color: AdminColors.zinc900,
  );

  static const headingLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w900,
    height: 1.2,
    letterSpacing: -0.3,
    color: AdminColors.zinc900,
  );

  static const heading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AdminColors.zinc900,
  );

  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AdminColors.zinc500,
  );

  static const small = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AdminColors.zinc500,
  );

  static const micro = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.5,
    color: AdminColors.zinc400,
  );

  static const statNumber = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    height: 1.0,
    color: AdminColors.zinc900,
  );

  static const statLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.5,
    color: AdminColors.zinc400,
  );
}

class AdminRadius {
  static const small = 8.0;
  static const medium = 10.0;
  static const large = 16.0;
  static const xLarge = 20.0;
  static const xxLarge = 24.0;
  static const huge = 32.0;
  static const massive = 40.0;
  static const icon = 20.0;
}

class AdminSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const huge = 32.0;
  static const massive = 48.0;
}

class AdminShadows {
  static List<BoxShadow> elevation1 = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];
  static List<BoxShadow> elevation2 = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.07),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  static List<BoxShadow> elevation3 = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> elevation4 = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> emeraldGlow = [
    BoxShadow(
      color: AdminColors.emerald500.withValues(alpha: 0.2),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
  static List<BoxShadow> roseGlow = [
    BoxShadow(
      color: AdminColors.rose500.withValues(alpha: 0.2),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
}
