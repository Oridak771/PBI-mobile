import 'package:flutter/widgets.dart';

/// Registry of every image shown by the app.
///
/// Every place the legacy app displayed a picture asks this registry first and
/// falls back to a text rendition when it returns `null` (the tile/tab code in
/// upper case, or a styled "GSH" / "CBI" text for logos).
///
/// Brand images (Portail BI) live in `assets/images/brand/`. The `*_on_dark`
/// variants have light lettering for dark backgrounds; the plain ones have
/// dark lettering for the light theme. Theme-aware slots take the current
/// `Theme.of(context).brightness`.
///
/// Pôle / société logos are not assets: they come from the catalog
/// (`logo_url`, see `GroupLogo`).
///
/// To wire an image:
/// 1. put the file under `assets/images/…` (`brand/` and `legacy/` are
///    declared in pubspec; add new folders to `pubspec.yaml`),
/// 2. set the matching slot below, or add `'DFC': 'assets/images/legacy/dfc.png'`
///    to [codeImages].
abstract final class AppAssets {
  static const String _brand = 'assets/images/brand';

  static const String pbiMarkOnDark = '$_brand/pbi_mark_on_dark.png';
  static const String pbiMarkOnLight = '$_brand/pbi_mark.png';
  static const String portailLogoOnDark = '$_brand/portail_bi_logo_on_dark.png';
  static const String portailLogoOnLight = '$_brand/portail_bi_logo.png';

  /// Splash screen logo (the splash is always dark).
  static const String splashLogo = pbiMarkOnDark;

  static String pbiMark(Brightness brightness) =>
      brightness == Brightness.dark ? pbiMarkOnDark : pbiMarkOnLight;

  static String portailLogo(Brightness brightness) =>
      brightness == Brightness.dark ? portailLogoOnDark : portailLogoOnLight;

  /// Login screen top logo (legacy `gsh_login`).
  static String loginLogo(Brightness brightness) => portailLogo(brightness);

  /// Small logo on the right of the shell header (legacy `gsh_white_small`).
  static String headerLogo(Brightness brightness) => pbiMark(brightness);

  /// Logo at the top of the "À propos" screen (legacy `cbi_dark`).
  static String aboutLogo(Brightness brightness) => portailLogo(brightness);

  /// Footer logo pinned at the bottom of the login screen (legacy `cbi_dark`).
  /// Not chosen yet: the footer stays empty while this is `null`.
  static const String? footerLogo = null;

  /// Images keyed by section / group / tab `code` (upper case, e.g. `DFC`,
  /// `MDM`, `CONSOLIDE`) or by lower-case name (e.g. `alpostone`).
  /// Empty for now: every tile/card shows its code as text.
  static const Map<String, String> codeImages = {};

  /// Image for a group/tab, looked up by code first, then by name.
  static String? forCode(String? code, {String? name}) {
    final c = code?.trim().toUpperCase() ?? '';
    if (c.isNotEmpty && codeImages[c] != null) return codeImages[c];
    final n = name?.trim().toLowerCase() ?? '';
    if (n.isNotEmpty && codeImages[n] != null) return codeImages[n];
    return null;
  }
}
