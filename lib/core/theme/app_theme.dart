import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const ink = Color(0xFF33272D);
  static const paper = Color(0xFFFFF8FA);
  static const sand = Color(0xFFFAEDF1);
  static const rose = Color(0xFFC76D88);
  static const roseHover = Color(0xFFA94E6B);
  static const deepRose = Color(0xFF783D52);
  static const mutedText = Color(0xFF62545A);
  static const softBorder = Color(0xFFEAD8DF);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: rose,
      brightness: Brightness.light,
      primary: rose,
      onPrimary: paper,
      primaryContainer: const Color(0xFFF3DBE3),
      onPrimaryContainer: deepRose,
      secondary: deepRose,
      onSecondary: paper,
      surface: paper,
      onSurface: ink,
      onSurfaceVariant: mutedText,
      outline: softBorder,
      outlineVariant: softBorder,
      error: const Color(0xFF9C3434),
      onError: paper,
    );
    final baseTextTheme = ThemeData.light().textTheme.apply(
      bodyColor: ink,
      displayColor: ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: paper,
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          fontFamily: 'serif',
          color: ink,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          fontFamily: 'serif',
          color: ink,
        ),
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          fontFamily: 'serif',
          color: ink,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontFamily: 'serif',
          color: ink,
          fontWeight: FontWeight.w500,
          height: 1.15,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontFamily: 'serif',
          color: ink,
          fontWeight: FontWeight.w500,
          height: 1.15,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          fontFamily: 'serif',
          color: ink,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(height: 1.6),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: mutedText,
          height: 1.6,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: paper,
          disabledBackgroundColor: ink.withValues(alpha: 0.45),
          disabledForegroundColor: paper,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: softBorder),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: deepRose,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFDFD),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        labelStyle: const TextStyle(color: mutedText),
        hintStyle: const TextStyle(color: Color(0xFF83757A)),
        prefixIconColor: mutedText,
        suffixIconColor: mutedText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: softBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: roseHover, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
    );
  }
}
