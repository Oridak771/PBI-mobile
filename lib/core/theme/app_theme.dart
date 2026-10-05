import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_dimens.dart';
import 'app_palette.dart';

/// Material 3 theme reproducing the Portail BI web platform: flat surfaces,
/// 1px borders instead of elevation, green primary, Roboto (the Android system
/// font, nothing bundled).
ThemeData buildAppTheme([Brightness brightness = Brightness.dark]) =>
    buildThemeFromPalette(AppPalette.of(brightness));

ThemeData buildLightTheme() => buildAppTheme(Brightness.light);
ThemeData buildDarkTheme() => buildAppTheme(Brightness.dark);

/// Status / navigation bar icons readable on [palette.background].
SystemUiOverlayStyle systemOverlayFor(AppPalette palette) =>
    (palette.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
        .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        );

ThemeData buildThemeFromPalette(AppPalette p) {
  final scheme = ColorScheme(
    brightness: p.brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.primarySoft,
    onPrimaryContainer: p.primaryText,
    secondary: p.primary,
    onSecondary: p.onPrimary,
    error: p.danger,
    onError: Colors.white,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.textMuted,
    surfaceContainerLowest: p.surface,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceAlt,
    surfaceContainerHighest: p.surfaceAlt,
    outline: p.border,
    outlineVariant: p.border,
    surfaceTint: Colors.transparent,
    shadow: Colors.transparent,
  );

  final controlRadius = BorderRadius.circular(AppDimens.radiusControl);
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppDimens.radiusCard),
    side: BorderSide(color: p.border),
  );
  final sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppDimens.radiusSheet),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    colorScheme: scheme,
  );
  final textTheme = base.textTheme.apply(
    bodyColor: p.text,
    displayColor: p.text,
  );
  // Component text styles replace (not merge) the defaults: start from the
  // theme's label style so they keep the system font.
  final label = textTheme.labelLarge ?? const TextStyle();
  TextStyle t(double size, FontWeight weight, {double? letterSpacing}) =>
      label.copyWith(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
      );

  return base.copyWith(
    extensions: [p],
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    textTheme: textTheme,
    dividerColor: p.border,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: systemOverlayFor(p),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape,
      clipBehavior: Clip.antiAlias,
    ),
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: p.textMuted),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.primary,
      selectionColor: p.primary.withValues(alpha: 0.35),
      selectionHandleColor: p.primary,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: p.surfaceAlt,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: p.textSubtle),
      labelStyle: TextStyle(color: p.textMuted),
      floatingLabelStyle: TextStyle(color: p.primaryText),
      helperStyle: TextStyle(color: p.textSubtle),
      errorStyle: TextStyle(color: p.danger),
      prefixIconColor: p.textSubtle,
      suffixIconColor: p.textSubtle,
      border: OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide(color: p.surfaceAlt),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide(color: p.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide(color: p.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide(color: p.danger, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        disabledBackgroundColor: p.primary.withValues(alpha: 0.5),
        disabledForegroundColor: p.onPrimary.withValues(alpha: 0.7),
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
        textStyle: t(15, FontWeight.bold, letterSpacing: 0.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 0,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
        textStyle: t(15, FontWeight.bold),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        minimumSize: const Size(64, 48),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
        textStyle: t(15, FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primaryText,
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
        textStyle: t(14, FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.textMuted),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: controlRadius),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: p.border)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : p.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.textMuted,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.textMuted,
        ),
        textStyle: WidgetStatePropertyAll(t(13, FontWeight.w600)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: p.primary.withValues(alpha: 0.18),
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 24,
          color: s.contains(WidgetState.selected) ? p.primaryText : p.textMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? p.primaryText : p.textMuted,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: p.surface,
      elevation: 0,
      indicatorColor: p.primary.withValues(alpha: 0.18),
      indicatorShape: const StadiumBorder(),
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: IconThemeData(size: 24, color: p.primaryText),
      unselectedIconTheme: IconThemeData(size: 24, color: p.textMuted),
      selectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: p.primaryText,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: p.textMuted,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.primaryText,
      unselectedLabelColor: p.textMuted,
      indicatorColor: p.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: p.border,
      overlayColor: WidgetStatePropertyAll(p.primary.withValues(alpha: 0.08)),
      labelStyle: t(14, FontWeight.w600),
      unselectedLabelStyle: t(14, FontWeight.w500),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.isDark ? p.surfaceAlt : p.text,
      contentTextStyle: TextStyle(
        color: p.isDark ? p.text : p.surface,
        fontSize: 14,
      ),
      actionTextColor: p.primary,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(
        borderRadius: controlRadius,
        side: p.isDark ? BorderSide(color: p.border) : BorderSide.none,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: sheetShape.copyWith(side: BorderSide(color: p.border)),
      titleTextStyle: TextStyle(
        color: p.text,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(color: p.textMuted, fontSize: 15, height: 1.4),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: p.surface,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: p.border,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusSheet + 4),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: controlRadius,
        side: BorderSide(color: p.border),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.textMuted,
      textColor: p.text,
      titleTextStyle: TextStyle(
        color: p.text,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: TextStyle(color: p.textMuted, fontSize: 13),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.isDark ? p.surfaceAlt : p.text,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(color: p.isDark ? p.text : p.surface, fontSize: 12),
    ),
    badgeTheme: BadgeThemeData(backgroundColor: p.danger),
  );
}
