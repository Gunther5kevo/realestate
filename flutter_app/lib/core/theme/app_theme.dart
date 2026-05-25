import 'package:flutter/material.dart';

/// NestIQ Design System — Clean, minimal, professional real estate aesthetic
class AppTheme {
  AppTheme._();

  // ─── Color Palette ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1E3A5F);        // Deep navy
  static const Color primaryLight = Color(0xFF2D5183);
  static const Color primarySurface = Color(0xFFEBF0F7);

  static const Color accent = Color(0xFF4A8C74);         // Muted sage green
  static const Color accentLight = Color(0xFF6BAF96);
  static const Color accentSurface = Color(0xFFEAF3EE);

  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF2F4F7);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color divider = Color(0xFFF0F0F0);

  static const Color success = Color(0xFF059669);
  static const Color successSurface = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSurface = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFDC2626);
  static const Color errorSurface = Color(0xFFFEF2F2);

  // Status colors
  static const Color statusActive = Color(0xFF059669);
  static const Color statusPending = Color(0xFFD97706);
  static const Color statusSold = Color(0xFF6B7280);
  static const Color statusRented = Color(0xFF4A8C74);

  // ─── Typography ─────────────────────────────────────────────────────────────
  static const String fontFamily = 'DM Sans';
  static const String fontFamilyDisplay = 'DM Serif Display';

  static TextTheme get textTheme => const TextTheme(
        displayLarge: TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 40,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.5,
          color: textPrimary,
          height: 1.15,
        ),
        displayMedium: TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 32,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.3,
          color: textPrimary,
          height: 1.2,
        ),
        displaySmall: TextStyle(
          fontFamily: fontFamilyDisplay,
          fontSize: 26,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.25,
        ),
        headlineLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        bodyLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.55,
        ),
        bodySmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: textPrimary,
        ),
        labelMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          color: textTertiary,
        ),
      );

  // ─── ThemeData ───────────────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          primary: primary,
          onPrimary: textOnPrimary,
          secondary: accent,
          surface: surface,
          background: background,
          error: error,
        ),
        scaffoldBackgroundColor: background,
        textTheme: textTheme,
        fontFamily: fontFamily,
        appBarTheme: AppBarTheme(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          shadowColor: border.withOpacity(0.5),
          centerTitle: false,
          titleTextStyle: textTheme.headlineSmall,
          iconTheme: const IconThemeData(color: textPrimary, size: 22),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: primary,
          unselectedItemColor: textTertiary,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: textOnPrimary,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: const BorderSide(color: border, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primary,
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: error, width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(
            fontFamily: fontFamily,
            color: textTertiary,
            fontSize: 14,
          ),
          labelStyle: const TextStyle(
            fontFamily: fontFamily,
            color: textSecondary,
            fontSize: 14,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: surfaceVariant,
          selectedColor: primarySurface,
          labelStyle: textTheme.labelMedium,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          side: BorderSide.none,
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: border, width: 0.5),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(color: divider, thickness: 1, space: 0),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: textPrimary,
          contentTextStyle: textTheme.bodyMedium?.copyWith(color: textOnPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  // ─── Spacing ─────────────────────────────────────────────────────────────────
  static const double spaceXS = 4;
  static const double spaceSM = 8;
  static const double spaceMD = 16;
  static const double spaceLG = 24;
  static const double spaceXL = 32;
  static const double space2XL = 48;

  // ─── Border Radius ───────────────────────────────────────────────────────────
  static const double radiusSM = 8;
  static const double radiusMD = 12;
  static const double radiusLG = 16;
  static const double radiusXL = 20;
  static const double radiusFull = 999;

  // ─── Shadows ─────────────────────────────────────────────────────────────────
  static List<BoxShadow> get shadowSM => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowMD => [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get shadowLG => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
}