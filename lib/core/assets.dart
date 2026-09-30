/// Registry of every image shown by the app.
///
/// Every place the legacy app displayed a picture asks this registry first and
/// falls back to a text rendition when it returns `null` (the tile/tab code in
/// upper case, or a styled "GSH" / "CBI" text for logos).
///
/// Brand images (Portail BI) live in `assets/images/brand/`. The `*_on_dark`
/// variants have light lettering for the #1C1D22 background.
///
/// To wire an image:
/// 1. put the file under `assets/images/…` (`brand/` and `legacy/` are
///    declared in pubspec; add new folders to `pubspec.yaml`),
/// 2. set the matching slot below, e.g. `splashLogo = 'assets/images/legacy/cbi.png'`
///    or add `'DFC': 'assets/images/legacy/dfc.png'` to [codeImages].
abstract final class AppAssets {
  static const String _brand = 'assets/images/brand';

  /// Splash screen logo (legacy `cbi_login`).
  static const String splashLogo = '$_brand/pbi_mark_on_dark.png';

  /// Login screen top logo (legacy `gsh_login`).
  static const String loginLogo = '$_brand/portail_bi_logo_on_dark.png';

  /// Small logo on the right of the shell header (legacy `gsh_white_small`).
  static const String headerLogo = '$_brand/pbi_mark_on_dark.png';

  /// Footer logo pinned at the bottom of the login screen (legacy `cbi_dark`).
  /// Not chosen yet: the footer stays empty while this is `null`.
  static const String? footerLogo = null;

  /// Logo at the top of the "À propos" screen (legacy `cbi_dark`).
  static const String aboutLogo = '$_brand/portail_bi_logo_on_dark.png';

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
