import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Dimensions of the legacy app (res/values/dimens.xml, default bucket).
abstract final class AppDimens {
  /// Tile side (`divider_padding`).
  static const tile = 70.0;
  static const consolideCardWidth = 60.0;
  static const consolideCardHeight = 80.0;

  /// `middle`.
  static const middle = 40.0;
  static const shellHeaderHeight = 65.0;
  static const screenHeaderHeight = 50.0;
  static const viewerHeaderHeight = 45.0;
  static const reportRowHeight = 65.0;

  /// Société grid rows (3 on tablets >= 600dp wide).
  static int societeGridRows(double screenWidth) => screenWidth >= 600 ? 3 : 2;
}

/// Legacy `android:shadow*` text shadows.
abstract final class AppShadows {
  static const white335 = [
    Shadow(color: AppColors.textShadowWhite, offset: Offset(3, 3), blurRadius: 5),
  ];
  static const dark335 = [
    Shadow(color: AppColors.textShadow, offset: Offset(3, 3), blurRadius: 5),
  ];
  static const dark223 = [
    Shadow(color: AppColors.textShadow, offset: Offset(2, 2), blurRadius: 3),
  ];
  static const dark222 = [
    Shadow(color: AppColors.textShadow, offset: Offset(2, 2), blurRadius: 2),
  ];
}
