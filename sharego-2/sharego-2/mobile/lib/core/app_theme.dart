import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Palette
  static const Color primary = Color(0xFF114550);
  static const Color primaryDark = Color(0xFF0D353F);
  static const Color primaryLight = Color(0xFFE7EDEF);
  static const Color primarySurface = Color(0xFFE7EDEF);
  static const Color amber = Color(0xFF114550);
  static const Color surface = Color(0xFFE7EDEF);
  static const Color success = Color(0xFF1E9E6A);
  static const Color danger = Color(0xFFD64550);
  static const Color textPrimary = Color(0xFF040406);
  static const Color textSecondary = Color(0xFF114550);

  // Spacing
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;

  // Border radius
  static const double borderRadius = 14.0;

  static ThemeData theme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: amber,
      surface: surface,
      error: danger,
    );

    final baseTextTheme = GoogleFonts.poppinsTextTheme().apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
      fontFamilyFallback: const ['Noto Nastaliq Urdu'],
    );

    final textTheme = baseTextTheme.copyWith(
      titleLarge: baseTextTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
      titleMedium:
          baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall:
          baseTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge:
          baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: textPrimary),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textSecondary),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: textTheme.bodyMedium
            ?.copyWith(color: textSecondary.withValues(alpha: 0.8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: primaryDark, width: 1.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primaryLight,
        labelStyle: textTheme.bodyMedium!,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(
          space: 1, thickness: 1, color: Color(0xFFE5E7EB)),
    );
  }

  static ThemeData darkTheme() {
    const darkSurface = Color(0xFF121212);
    const darkCard = Color(0xFF1E1E1E);
    const darkAppBar = Color(0xFF1A1A1A);
    const darkInput = Color(0xFF2A2A2A);
    const darkTextPrimary = Color(0xFFE0E0E0);
    const darkTextSecondary = Color(0xFFA0A0A0);
    const darkDivider = Color(0xFF2E2E2E);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      secondary: amber,
      surface: darkSurface,
      error: danger,
    );

    final baseTextTheme = GoogleFonts.poppinsTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: darkTextPrimary,
      displayColor: darkTextPrimary,
      fontFamilyFallback: const ['Noto Nastaliq Urdu'],
    );

    final textTheme = baseTextTheme.copyWith(
      titleLarge: baseTextTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
      titleMedium:
          baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall:
          baseTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge:
          baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: darkTextPrimary),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: darkTextSecondary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkSurface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: darkAppBar,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: darkCard,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInput,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: textTheme.bodyMedium
            ?.copyWith(color: darkTextSecondary.withValues(alpha: 0.8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: primary, width: 1.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkCard,
        selectedColor: primaryDark,
        labelStyle: textTheme.bodyMedium!,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(
          space: 1, thickness: 1, color: darkDivider),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkAppBar,
        selectedItemColor: primary,
        unselectedItemColor: darkTextSecondary,
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: darkCard),
      dialogTheme: const DialogThemeData(backgroundColor: darkCard),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCard,
        contentTextStyle: textTheme.bodyMedium,
      ),
    );
  }
}
