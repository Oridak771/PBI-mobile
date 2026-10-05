import 'package:flutter/material.dart';

/// Colour tokens of the Portail BI "glass" style, light and dark.
///
/// Widgets read them with `context.palette` (never hard-coded colours), so
/// the whole app follows the selected [ThemeMode]. The values come from the
/// approved mockup (`docs/design/mockup.html`).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.backgroundTop,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.divider,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.primary,
    required this.onPrimary,
    required this.primaryText,
    required this.primaryBright,
    required this.danger,
    required this.success,
    required this.warning,
    required this.glassTop,
    required this.glassBottom,
    required this.glassBorder,
    required this.glassHighlight,
    required this.glassShadow,
    required this.glassSelected,
    required this.glowGreen,
    required this.glowTeal,
    required this.glowBlue,
    required this.tileBlue,
    required this.tileAmber,
    required this.skeleton,
  });

  static const dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0C0E11),
    backgroundTop: Color(0xFF121519),
    surface: Color(0xFF181B20),
    surfaceAlt: Color(0x0FFFFFFF), // white 6%: inputs, wells
    border: Color(0x29FFFFFF), // white 16%
    divider: Color(0x14FFFFFF), // white 8%
    text: Color(0xFFF5F6F8),
    textMuted: Color(0x9EEBEEF3), // rgba(235,238,243,.62)
    textSubtle: Color(0x75EBEEF3), // rgba(235,238,243,.46)
    primary: Color(0xFFA5CF4B),
    onPrimary: Color(0xFF10140A),
    primaryText: Color(0xFFB9E06A),
    primaryBright: Color(0xFFC8EA82),
    danger: Color(0xFFF87171),
    success: Color(0xFF8EE0B0),
    warning: Color(0xFFF0C886),
    glassTop: Color(0x24FFFFFF), // white 14%
    glassBottom: Color(0x0AFFFFFF), // white 4%
    glassBorder: Color(0x29FFFFFF), // white 16%
    glassHighlight: Color(0x47FFFFFF), // white 28%
    glassShadow: Color(0x40000000), // black 25%
    glassSelected: Color(0x1FFFFFFF), // white 12%
    glowGreen: Color(0x8CA5CF4B), // rgba(165,207,75,.55)
    glowTeal: Color(0x6626A69A), // rgba(38,166,154,.40)
    glowBlue: Color(0x527CC4E8), // rgba(124,196,232,.32)
    tileBlue: Color(0xFF9BD3F0),
    tileAmber: Color(0xFFF0C886),
    skeleton: Color(0x1AFFFFFF),
  );

  static const light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF3F5F8),
    backgroundTop: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0x99FFFFFF), // white 60%: inputs, wells
    border: Color(0x141B1E24),
    divider: Color(0x121B1E24),
    text: Color(0xFF1B1E24),
    textMuted: Color(0xFF5F6168),
    textSubtle: Color(0xFF8A8D94),
    primary: Color(0xFFA5CF4B),
    onPrimary: Color(0xFF10140A),
    // Green text on light backgrounds (the brand green is too pale on white).
    primaryText: Color(0xFF5E8A1F),
    primaryBright: Color(0xFF5E8A1F),
    danger: Color(0xFFDC2626),
    success: Color(0xFF2E9E62),
    warning: Color(0xFFB7791F),
    glassTop: Color(0xB8FFFFFF), // white 72%
    glassBottom: Color(0x99FFFFFF), // white 60%
    glassBorder: Color(0xE6FFFFFF),
    glassHighlight: Color(0xFFFFFFFF),
    glassShadow: Color(0x141B1E24),
    glassSelected: Color(0x1A5E8A1F),
    glowGreen: Color(0x4DA5CF4B),
    glowTeal: Color(0x2E26A69A),
    glowBlue: Color(0x337CC4E8),
    tileBlue: Color(0xFF2F7FA8),
    tileAmber: Color(0xFFA8711E),
    skeleton: Color(0x141B1E24),
  );

  static AppPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  final Brightness brightness;

  /// Page background (bottom of the base gradient).
  final Color background;

  /// Top of the base gradient behind the glows.
  final Color backgroundTop;

  /// Opaque surface: menus, snackbars, dialogs fallback.
  final Color surface;

  /// Inputs, icon wells, secondary blocks (translucent).
  final Color surfaceAlt;

  /// 1px borders.
  final Color border;

  /// Separators inside glass panels.
  final Color divider;
  final Color text;
  final Color textMuted;
  final Color textSubtle;

  /// Brand green: buttons, indicators, accents.
  final Color primary;

  /// Text / icons drawn on [primary] (and on the green gradient).
  final Color onPrimary;

  /// Green used for text and icons on the background / glass.
  final Color primaryText;

  /// Lighter green of the selected navigation item and status pills.
  final Color primaryBright;
  final Color danger;

  /// Teal green (closed tickets).
  final Color success;

  /// Amber (medium priority, "En cours").
  final Color warning;

  /// Glass fill gradient (135°), border, inner top highlight, drop shadow.
  final Color glassTop;
  final Color glassBottom;
  final Color glassBorder;
  final Color glassHighlight;
  final Color glassShadow;

  /// Lit pill of the selected tab / rail item.
  final Color glassSelected;

  /// Radial glows of the background.
  final Color glowGreen;
  final Color glowTeal;
  final Color glowBlue;

  /// Icon colours of the blue / amber report tiles.
  final Color tileBlue;
  final Color tileAmber;

  /// Skeleton placeholder blocks.
  final Color skeleton;

  bool get isDark => brightness == Brightness.dark;

  /// Opaque glass of dialogs, menus and non-blurred sheets.
  Color get sheet => isDark ? const Color(0xFA1A1E24) : const Color(0xFAFFFFFF);

  /// Focused input border: rgba(185,224,106,.7) in dark.
  Color get focusBorder => primaryText.withValues(alpha: 0.7);

  /// Soft green tint (icon wells, unread accents).
  Color get primarySoft => primary.withValues(alpha: 0.22);

  /// Top / bottom of the green gradient of primary buttons and chips.
  Color get gradientTop => const Color(0xFFB6DD62);
  Color get gradientBottom => const Color(0xFF93BF3A);

  @override
  AppPalette copyWith({Brightness? brightness, Color? background}) =>
      AppPalette(
        brightness: brightness ?? this.brightness,
        background: background ?? this.background,
        backgroundTop: backgroundTop,
        surface: surface,
        surfaceAlt: surfaceAlt,
        border: border,
        divider: divider,
        text: text,
        textMuted: textMuted,
        textSubtle: textSubtle,
        primary: primary,
        onPrimary: onPrimary,
        primaryText: primaryText,
        primaryBright: primaryBright,
        danger: danger,
        success: success,
        warning: warning,
        glassTop: glassTop,
        glassBottom: glassBottom,
        glassBorder: glassBorder,
        glassHighlight: glassHighlight,
        glassShadow: glassShadow,
        glassSelected: glassSelected,
        glowGreen: glowGreen,
        glowTeal: glowTeal,
        glowBlue: glowBlue,
        tileBlue: tileBlue,
        tileAmber: tileAmber,
        skeleton: skeleton,
      );

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      backgroundTop: c(backgroundTop, other.backgroundTop),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      border: c(border, other.border),
      divider: c(divider, other.divider),
      text: c(text, other.text),
      textMuted: c(textMuted, other.textMuted),
      textSubtle: c(textSubtle, other.textSubtle),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryText: c(primaryText, other.primaryText),
      primaryBright: c(primaryBright, other.primaryBright),
      danger: c(danger, other.danger),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      glassTop: c(glassTop, other.glassTop),
      glassBottom: c(glassBottom, other.glassBottom),
      glassBorder: c(glassBorder, other.glassBorder),
      glassHighlight: c(glassHighlight, other.glassHighlight),
      glassShadow: c(glassShadow, other.glassShadow),
      glassSelected: c(glassSelected, other.glassSelected),
      glowGreen: c(glowGreen, other.glowGreen),
      glowTeal: c(glowTeal, other.glowTeal),
      glowBlue: c(glowBlue, other.glowBlue),
      tileBlue: c(tileBlue, other.tileBlue),
      tileAmber: c(tileAmber, other.tileAmber),
      skeleton: c(skeleton, other.skeleton),
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// Palette of the current theme (light or dark).
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ??
      AppPalette.of(Theme.of(this).brightness);
}
