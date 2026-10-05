import 'package:flutter/material.dart';

/// Colour tokens of the Portail BI web platform, light and dark.
///
/// Widgets read them with `context.palette` (never hard-coded colours), so
/// the whole app follows the selected [ThemeMode].
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.primary,
    required this.onPrimary,
    required this.primaryText,
    required this.danger,
    required this.success,
    required this.warning,
  });

  static const dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF111318),
    surface: Color(0xFF1C1D22),
    surfaceAlt: Color(0xFF25262D),
    border: Color(0xFF34353D),
    text: Color(0xFFF1F2F4),
    textMuted: Color(0xFFA8ABB4),
    textSubtle: Color(0xFF8F9097),
    primary: Color(0xFFA5CF4B),
    onPrimary: Color(0xFF1C1D22),
    primaryText: Color(0xFFA5CF4B),
    danger: Color(0xFFEF4444),
    success: Color(0xFF42B883),
    warning: Color(0xFFF59E0B),
  );

  static const light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF5F5F5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F2F4),
    border: Color(0xFFE4E4E6),
    text: Color(0xFF2A2B30),
    textMuted: Color(0xFF5F6168),
    textSubtle: Color(0xFF8F9097),
    primary: Color(0xFFA5CF4B),
    onPrimary: Color(0xFF1C1D22),
    // Green text on light backgrounds (the brand green is too pale on white).
    primaryText: Color(0xFF71952B),
    danger: Color(0xFFDC2626),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
  );

  static AppPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  final Brightness brightness;

  /// Page background.
  final Color background;

  /// Cards, bars, sheets, dialogs.
  final Color surface;

  /// Inputs, icon wells, secondary blocks.
  final Color surfaceAlt;

  /// 1px borders and dividers (no elevation in this design).
  final Color border;
  final Color text;
  final Color textMuted;
  final Color textSubtle;

  /// Brand green: buttons, indicators, accents.
  final Color primary;

  /// Text / icons drawn on [primary].
  final Color onPrimary;

  /// Green used for text and icons on [background] / [surface].
  final Color primaryText;
  final Color danger;
  final Color success;

  /// Amber (medium priority).
  final Color warning;

  bool get isDark => brightness == Brightness.dark;

  /// Soft green tint (icon wells, selected pills, unread accents).
  Color get primarySoft => primary.withValues(alpha: 0.12);

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? textSubtle,
    Color? primary,
    Color? onPrimary,
    Color? primaryText,
    Color? danger,
    Color? success,
    Color? warning,
  }) => AppPalette(
    brightness: brightness ?? this.brightness,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    border: border ?? this.border,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    textSubtle: textSubtle ?? this.textSubtle,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    primaryText: primaryText ?? this.primaryText,
    danger: danger ?? this.danger,
    success: success ?? this.success,
    warning: warning ?? this.warning,
  );

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      border: c(border, other.border),
      text: c(text, other.text),
      textMuted: c(textMuted, other.textMuted),
      textSubtle: c(textSubtle, other.textSubtle),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryText: c(primaryText, other.primaryText),
      danger: c(danger, other.danger),
      success: c(success, other.success),
      warning: c(warning, other.warning),
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// Palette of the current theme (light or dark).
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ??
      AppPalette.of(Theme.of(this).brightness);
}
