import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Light iOS 27 Editorial + Liquid Glass tokens
  static const Color lightBackground = Color(0xFFF4F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFEBEFF5);
  static const Color lightBorder = Color(0xFFE1E5EE);
  static const Color lightTextPrimary = Color(0xFF0F1115);
  static const Color lightTextSecondary = Color(0xFF5A616C);
  static const Color lightTextMuted = Color(0xFF8A919E);

  // Dark iOS 27 OLED + Liquid Glass tokens
  static const Color darkBackground = Color(0xFF090B0F);
  static const Color darkSurface = Color(0xFF151920);
  static const Color darkSurfaceMuted = Color(0xFF1F2530);
  static const Color darkBorder = Color(0x22FFFFFF);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFB0B8C5);
  static const Color darkTextMuted = Color(0xFF747D8B);

  // Authentic Apple iOS System Accents
  static const Color iosBlue = Color(0xFF007AFF);
  static const Color iosGreen = Color(0xFF34C759);
  static const Color iosPink = Color(0xFFFF2D55);
  static const Color iosOrange = Color(0xFFFF9500);
  static const Color iosIndigo = Color(0xFF5856D6);
  static const Color iosTeal = Color(0xFF30B0C7);
  static const Color iosRed = Color(0xFFFF3B30);

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

  static const Color error = Color(0xFFFF3B30);
  static const Color success = Color(0xFF34C759);

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
    final seed = dynamicSeed ?? AppColors.iosBlue;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: AppColors.lightSurface,
      primary: AppColors.lightTextPrimary,
      onPrimary: Colors.white,
      secondary: AppColors.iosBlue,
      onSecondary: Colors.white,
    );

    final baseText = GoogleFonts.interTextTheme(ThemeData.light().textTheme);
    final displayStyle = GoogleFonts.inter();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      canvasColor: AppColors.lightBackground,
      dividerColor: AppColors.lightBorder,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: AppColors.lightTextPrimary.withAlpha(14),
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.iosBlue,
        barBackgroundColor: Color(0xCCF4F6FA),
        scaffoldBackgroundColor: AppColors.lightBackground,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      iconTheme: const IconThemeData(
        color: AppColors.lightTextPrimary,
        size: 22,
      ),
      textTheme: baseText.copyWith(
        headlineLarge: displayStyle.copyWith(
          fontSize: 31,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.95,
          height: 1.10,
          color: AppColors.lightTextPrimary,
        ),
        headlineMedium: displayStyle.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.55,
          height: 1.16,
          color: AppColors.lightTextPrimary,
        ),
        titleLarge: displayStyle.copyWith(
          fontSize: 18.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
          color: AppColors.lightTextPrimary,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: AppColors.lightTextPrimary,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          fontSize: 14,
          letterSpacing: -0.1,
          color: AppColors.lightTextSecondary,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          fontSize: 12,
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
          letterSpacing: -0.45,
          color: AppColors.lightTextPrimary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.iosGreen;
          return const Color(0xFFD1D5DB);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lightTextPrimary,
          foregroundColor: Colors.white,
          textStyle: displayStyle.copyWith(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
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
            letterSpacing: -0.15,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceMuted,
        selectedColor: AppColors.lightTextPrimary,
        labelStyle: displayStyle.copyWith(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.15,
          color: AppColors.lightTextPrimary,
        ),
        secondaryLabelStyle: displayStyle.copyWith(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.15,
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
        thumbColor: Colors.white,
        overlayColor: AppColors.lightTextPrimary.withAlpha(20),
        trackHeight: 4.5,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 8,
          elevation: 2,
          pressedElevation: 4,
        ),
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
          borderSide: const BorderSide(color: AppColors.iosBlue, width: 1.2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xEE181B20),
        contentTextStyle: displayStyle.copyWith(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(56)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(52)),
        ),
      ),
    );
  }

  static ThemeData darkTheme({Color? dynamicSeed}) {
    final seed = dynamicSeed ?? AppColors.iosBlue;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: AppColors.darkSurface,
      primary: Colors.white,
      onPrimary: Colors.black,
      secondary: AppColors.lunarCyan,
    );

    final baseText = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    final displayStyle = GoogleFonts.inter();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      canvasColor: AppColors.darkBackground,
      dividerColor: AppColors.darkBorder,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.white.withAlpha(18),
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFF0A84FF),
        barBackgroundColor: Color(0xCC090B0F),
        scaffoldBackgroundColor: AppColors.darkBackground,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      iconTheme: const IconThemeData(
        color: AppColors.darkTextPrimary,
        size: 22,
      ),
      textTheme: baseText.copyWith(
        headlineLarge: displayStyle.copyWith(
          fontSize: 31,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.95,
          height: 1.10,
          color: AppColors.darkTextPrimary,
        ),
        headlineMedium: displayStyle.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.55,
          height: 1.16,
          color: AppColors.darkTextPrimary,
        ),
        titleLarge: displayStyle.copyWith(
          fontSize: 18.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
          color: AppColors.darkTextPrimary,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: AppColors.darkTextPrimary,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          fontSize: 14,
          letterSpacing: -0.1,
          color: AppColors.darkTextSecondary,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          fontSize: 12,
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
          letterSpacing: -0.45,
          color: AppColors.darkTextPrimary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.iosGreen;
          return const Color(0xFF393E48);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.lightTextPrimary,
          textStyle: displayStyle.copyWith(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
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
            letterSpacing: -0.15,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceMuted,
        selectedColor: Colors.white,
        labelStyle: displayStyle.copyWith(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.15,
          color: AppColors.darkTextPrimary,
        ),
        secondaryLabelStyle: displayStyle.copyWith(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.15,
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
        overlayColor: Colors.white.withAlpha(24),
        trackHeight: 4.5,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 8,
          elevation: 2,
          pressedElevation: 4,
        ),
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
          borderSide: const BorderSide(color: Color(0xFF0A84FF), width: 1.2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xEE1F242E),
        contentTextStyle: displayStyle.copyWith(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.darkBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(56)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(52)),
        ),
      ),
    );
  }
}
