import 'package:flutter/material.dart';

import 'app_colors.dart';

/// AJW BDS Portal light theme. Only a light theme exists for now — this
/// is an internal operations app for staff and MSME owners, not a
/// consumer product where dark mode is expected by default. Add a dark
/// variant later only if real user demand shows up for it.
final ThemeData ajwLightTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.surfaceLight,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.brandRed,
    primary: AppColors.brandRed,
    error: AppColors.errorRed,
    surface: AppColors.surfaceLight,
    onSurface: AppColors.textOnLight,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.charcoal,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.brandRed,
      foregroundColor: Colors.white,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: AppColors.brandRed),
  ),
  // Secondary/outline actions use a neutral charcoal outline, never red —
  // red stays reserved for primary brand actions and errors only.
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.charcoal,
      side: const BorderSide(color: AppColors.lightGray),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.brandRed, width: 2),
    ),
    errorBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.errorRed),
    ),
    labelStyle: const TextStyle(color: AppColors.textMuted),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.successGreen
          : AppColors.lightGray,
    ),
  ),
);