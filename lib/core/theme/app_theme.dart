import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material theme reproducing the legacy `AppTheme.NoActionBar` look.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.green,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.green,
    secondary: AppColors.blueGreen,
    surface: AppColors.black,
    error: AppColors.red,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.black,
    canvasColor: AppColors.black,
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.black),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.green,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surface,
      contentTextStyle: TextStyle(color: AppColors.gray, fontSize: 14),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.green,
      selectionHandleColor: AppColors.green,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.sheet),
  );
}
