/// Spacing, radii and sizes of the Portail BI style.
abstract final class AppDimens {
  /// Page side padding.
  static const page = 16.0;

  /// Cards / list rows.
  static const radiusCard = 14.0;

  /// Inputs, buttons, icon wells.
  static const radiusControl = 10.0;

  /// Sheets and dialogs.
  static const radiusSheet = 16.0;

  static const shellHeaderHeight = 64.0;
  static const screenHeaderHeight = 56.0;
  static const reportRowMinHeight = 64.0;

  /// Home group / direction cards: fixed width, logo tile, name under it.
  static const groupCardWidth = 88.0;
  static const groupCardHeight = 124.0;
  static const groupTile = 64.0;

  /// Horizontal gap between home cards.
  static const groupCardGap = 8.0;

  /// Société grid rows (3 on tablets >= 600dp wide).
  static int societeGridRows(double screenWidth) => screenWidth >= 600 ? 3 : 2;
}
