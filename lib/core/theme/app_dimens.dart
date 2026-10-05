/// Spacing, radii and sizes of the Portail BI glass style (from the approved
/// mockup, `docs/design/mockup.html`).
abstract final class AppDimens {
  /// Page side padding (18 in the mockup's lists, 16 for the tab bar).
  static const page = 18.0;

  /// Glass cards (récents, tickets, group cards).
  static const radiusCard = 20.0;

  /// Glass list panels (reports of a group, settings groups).
  static const radiusPanel = 24.0;

  /// Inputs and the login buttons.
  static const radiusControl = 15.0;

  /// Sheets and dialogs.
  static const radiusSheet = 24.0;

  /// Report icon tiles (40×40).
  static const radiusTile = 13.0;
  static const tile = 40.0;

  static const screenHeaderHeight = 60.0;
  static const reportRowMinHeight = 64.0;

  /// Floating glass tab bar: 16 from the sides, 18 from the bottom, 64 high.
  static const tabBarSide = 16.0;
  static const tabBarBottom = 18.0;
  static const tabBarHeight = 64.0;

  /// Space reserved under scrolling content for the floating tab bar.
  static const tabBarReserve = tabBarHeight + tabBarBottom + 12;

  /// Home group cards: logo tile size.
  static const groupLogo = 44.0;

  /// Récents cards: minimum width.
  static const recentCardWidth = 150.0;

  /// Gap between grid cards.
  static const gridGap = 9.0;

  /// Home grid columns: 3 on phones, more on tablets (cards ~ 120 wide).
  static int gridColumns(double width) =>
      width < 600 ? 3 : (width / 130).floor().clamp(4, 8);
}
