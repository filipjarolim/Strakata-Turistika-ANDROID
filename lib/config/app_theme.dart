import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'strakata_color_math.dart';
import 'strakata_design_tokens.dart';

/// Strakatá turistika — Material 3 theme aligned with web (warm off‑white, brand green).
class AppTheme {
  AppTheme._();

  /// Libre Baskerville for editorial / hero titles (use sparingly).
  static TextStyle editorialHeadline({Color? color, double fontSize = 28}) {
    return GoogleFonts.libreBaskerville(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      height: 1.25,
      color: color ?? AppColors.textPrimary,
    );
  }

  static ThemeData get lightTheme {
    final scheme = _colorScheme;
    final radii = StrakataThemeExtension.light;
    final baseText = ThemeData(brightness: Brightness.light, useMaterial3: true).textTheme;
    final franklin = GoogleFonts.libreFranklinTextTheme(baseText).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    final textTheme = franklin.copyWith(
      displayLarge: GoogleFonts.inter(
        textStyle: franklin.displayLarge,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      ),
      displayMedium: GoogleFonts.inter(
        textStyle: franklin.displayMedium,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.25,
        color: AppColors.textPrimary,
      ),
      displaySmall: GoogleFonts.inter(
        textStyle: franklin.displaySmall,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      headlineLarge: GoogleFonts.inter(
        textStyle: franklin.headlineLarge,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        textStyle: franklin.headlineMedium,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.inter(
        textStyle: franklin.headlineSmall,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        textStyle: franklin.titleLarge,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.libreFranklin(
        textStyle: franklin.titleMedium,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleSmall: GoogleFonts.libreFranklin(
        textStyle: franklin.titleSmall,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      bodyLarge: GoogleFonts.libreFranklin(
        textStyle: franklin.bodyLarge,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.libreFranklin(
        textStyle: franklin.bodyMedium,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.textSecondary,
      ),
      bodySmall: GoogleFonts.libreFranklin(
        textStyle: franklin.bodySmall,
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
      ),
      labelLarge: GoogleFonts.libreFranklin(
        textStyle: franklin.labelLarge,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
      ),
      labelMedium: GoogleFonts.libreFranklin(
        textStyle: franklin.labelMedium,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
      labelSmall: GoogleFonts.libreFranklin(
        textStyle: franklin.labelSmall,
        fontWeight: FontWeight.w500,
        color: AppColors.textTertiary,
      ),
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.pageBg,
      canvasColor: AppColors.pageBg,
      extensions: <ThemeExtension<dynamic>>[StrakataThemeExtension.light],
      visualDensity: VisualDensity.adaptivePlatformDensity,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,
      applyElevationOverlayColor: true,
      focusColor: AppColors.focusRing.withValues(alpha: 0.35),
      highlightColor: Colors.transparent,
      hoverColor: AppColors.brand.withValues(alpha: 0.06),
      textTheme: textTheme,
      primaryTextTheme: GoogleFonts.libreFranklinTextTheme(baseText).apply(
        bodyColor: scheme.onPrimary,
        displayColor: scheme.onPrimary,
      ),

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        backgroundColor: scheme.surface.withValues(alpha: 0.92),
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: AppColors.textPrimary, weight: 400),
      ),

      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.radiusLg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radii.radiusBase)),
          elevation: 0,
          textStyle: textTheme.labelLarge,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radii.radiusBase)),
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline, width: 1.5),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radii.radiusBase)),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radii.radiusBase)),
          textStyle: textTheme.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
        labelStyle: textTheme.bodyMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.radiusBase),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.radiusBase),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.radiusBase),
          borderSide: BorderSide(color: AppColors.focusRing, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.radiusBase),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),

      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radii.radiusApp)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radii.radiusApp)),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: strakataHsl(48, 12, 22),
        contentTextStyle: GoogleFonts.libreFranklin(color: Colors.white, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radii.radiusMd)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHighest,
        labelStyle: textTheme.labelMedium!,
        secondaryLabelStyle: textTheme.labelSmall,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radii.radiusSm)),
        side: BorderSide(color: scheme.outlineVariant),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radii.radiusLg)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface.withValues(alpha: 0.94),
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return GoogleFonts.libreFranklin(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.primary : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return IconThemeData(color: selected ? scheme.primary : AppColors.textSecondary, size: 24);
        }),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radii.radiusMd)),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, linearTrackColor: scheme.surfaceContainer),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.primary;
          return null;
        }),
        side: BorderSide(color: scheme.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radii.radiusSm)),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ColorScheme get _colorScheme {
    final primary = AppColors.brand;
    final onPrimary = Colors.white;
    final primaryContainer = AppColors.brandMuted;
    final onPrimaryContainer = strakataHsl(142, 72, 18);

    return ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.brandSubtle,
      onSecondaryContainer: AppColors.textPrimary,
      tertiary: strakataHsl(72, 55, 42),
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.heroOverlayTop,
      onTertiaryContainer: AppColors.textPrimary,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.pageBg,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.divider,
      shadow: AppColors.shadow,
      scrim: const Color(0x99000000),
      inverseSurface: strakataHsl(48, 12, 18),
      onInverseSurface: const Color(0xFFF5F5F0),
      inversePrimary: strakataHsl(142, 72, 75),
      surfaceTint: primary,
      surfaceContainerHighest: AppColors.surfaceVariant,
      surfaceContainerHigh: AppColors.surface,
      surfaceContainer: AppColors.surfaceMuted,
      surfaceContainerLow: strakataHsl(48, 26, 97),
      surfaceContainerLowest: Colors.white,
    );
  }

  static BoxDecoration get boxDecoration {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(StrakataRadii.lg),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: const Offset(0, 4)),
      ],
    );
  }

  static BoxDecoration get glassDecoration {
    return BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(StrakataRadii.app),
      border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      boxShadow: [
        BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 10)),
      ],
    );
  }
}
