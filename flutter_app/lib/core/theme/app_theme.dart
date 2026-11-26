import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Light Editorial + Liquid Glass tokens (primary look from reference)
  static const Color lightBackground = Color(0xFFF6F7F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFEFF1F4);
  static const Color lightBorder = Color(0xFFE6E8ED);
  static const Color lightTextPrimary = Color(0xFF111315);
  static const Color lightTextSecondary = Color(0xFF5D636C);
  static const Color lightTextMuted = Color(0xFF8A919C);

  // Dark Mode tokens
  static const Color darkBackground = Color(0xFF0B0D10);
  static const Color darkSurface = Color(0xFF15191F);
  static const Color darkSurfaceMuted = Color(0xFF1F242C);
  static const Color darkBorder = Color(0x1EFFFFFF);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFAEB6C2);
  static const Color darkTextMuted = Color(0xFF747D8A);

  // Brand Horizon Wave Ocean Slate Blue
  static const Color horizonBlue = Color(0xFF16466B);
  static const Color horizonBlueSoft = Color(0xFF215B88);

  // Legacy-friendly defaults mapped gracefully for context-free fallbacks
  static const Color background = lightBackground;
  static const Color backgroundDeep = darkBackground;
  static const Color surface = lightSurface;
  static const Color surfaceElevated = lightSurfaceMuted;
  static const Color surfaceHigh = Color(0xFFE4E7EC);
  static const Color border = lightBorder;
  static const Color borderStrong = Color(0xFFD5D9E2);

  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color textMuted = lightTextMuted;

  static const Color brandGreen = Color(0xFF111315);
  static const Color brandGreenBright = Color(0xFF16466B);
  static const Color brandDeep = Color(0xFF16466B);
  static const Color lunarCyan = Color(0xFF3B82F6);
  static const Color spotifyGreen = Color(0xFF1DB954);
  static const Color ytRed = Color(0xFFFF0033);

  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bgOf(BuildContext context) =>
      isDark(context) ? darkBackground : lightBackground;

  static Color cardOf(BuildContext context) =>
      isDark(context) ? darkSurface : lightSurface;

  static Color pillOf(BuildContext context) =>
      isDark(context) ? darkSurfaceMuted : lightSurfaceMuted;

  static Color borderOf(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorder;

  static Color inkOf(BuildContext context) =>
      isDark(context) ? darkTextPrimary : lightTextPrimary;

  static Color subOf(BuildContext context) =>
      isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color mutedOf(BuildContext context) =>
      isDark(context) ? darkTextMuted : lightTextMuted;
}

class AppTheme {
  static ThemeData lightTheme({Color? dynamicSeed}) {
    final seed = dynamicSeed ?? AppColors.horizonBlue;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: AppColors.lightSurface,
      primary: AppColors.lightTextPrimary,
      onPrimary: Colors.white,
      secondary: AppColors.horizonBlue,
      onSecondary: Colors.white,
    );

    final baseText = GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme);
    final displayStyle = GoogleFonts.plusJakartaSans();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      canvasColor: AppColors.lightBackground,
      dividerColor: AppColors.lightBorder,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashColor: AppColors.lightTextPrimary.withAlpha(14),
      highlightColor: AppColors.lightTextPrimary.withAlpha(10),
      textTheme: baseText.copyWith(
        headlineLarge: displayStyle.copyWith(
          fontSize: 31,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.9,
          color: AppColors.lightTextPrimary,
        ),
        headlineMedium: displayStyle.copyWith(
          fontSize: 23,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: AppColors.lightTextPrimary,
        ),
        titleLarge: displayStyle.copyWith(
          fontSize: 19.5,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: AppColors.lightTextPrimary,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          color: AppColors.lightTextPrimary,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          fontSize: 14,
          color: AppColors.lightTextSecondary,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          fontSize: 12.5,
          color: AppColors.lightTextMuted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: displayStyle.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: AppColors.lightTextPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lightTextPrimary,
          foregroundColor: Colors.white,
          textStyle: displayStyle.copyWith(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightTextPrimary,
          backgroundColor: AppColors.lightSurface,
          side: const BorderSide(color: AppColors.lightBorder),
          textStyle: displayStyle.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceMuted,
        selectedColor: AppColors.lightTextPrimary,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
        ),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.lightTextPrimary,
        inactiveTrackColor: AppColors.lightTextPrimary.withAlpha(32),
        thumbColor: AppColors.lightTextPrimary,
        overlayColor: AppColors.lightTextPrimary.withAlpha(24),
        trackHeight: 4.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceMuted,
        hintStyle: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 14.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.lightTextPrimary, width: 1.2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightTextPrimary,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
      ),
    );
  }

  static ThemeData darkTheme({Color? dynamicSeed}) {
    final seed = dynamicSeed ?? AppColors.horizonBlueSoft;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: AppColors.darkSurface,
      primary: Colors.white,
      onPrimary: Colors.black,
      secondary: AppColors.lunarCyan,
    );

    final baseText = GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme);
    final displayStyle = GoogleFonts.plusJakartaSans();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      canvasColor: AppColors.darkBackground,
      dividerColor: AppColors.darkBorder,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashColor: Colors.white.withAlpha(20),
      highlightColor: Colors.white.withAlpha(14),
      textTheme: baseText.copyWith(
        headlineLarge: displayStyle.copyWith(
          fontSize: 31,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.9,
          color: AppColors.darkTextPrimary,
        ),
        headlineMedium: displayStyle.copyWith(
          fontSize: 23,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: AppColors.darkTextPrimary,
        ),
        titleLarge: displayStyle.copyWith(
          fontSize: 19.5,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: AppColors.darkTextPrimary,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          fontSize: 14,
          color: AppColors.darkTextSecondary,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          fontSize: 12.5,
          color: AppColors.darkTextMuted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: displayStyle.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: AppColors.darkTextPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.lightTextPrimary,
          textStyle: displayStyle.copyWith(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkTextPrimary,
          backgroundColor: AppColors.darkSurfaceMuted,
          side: const BorderSide(color: AppColors.darkBorder),
          textStyle: displayStyle.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceMuted,
        selectedColor: Colors.white,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white.withAlpha(48),
        thumbColor: Colors.white,
        overlayColor: Colors.white.withAlpha(28),
        trackHeight: 4.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceMuted,
        hintStyle: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 14.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white, width: 1.2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurfaceMuted,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
      ),
    );
  }
}
