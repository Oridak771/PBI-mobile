import 'package:flutter/material.dart';

/// Fixed brand colours that do not depend on the light / dark theme.
///
/// Everything else comes from the theme palette (`context.palette`, see
/// `AppPalette`): widgets must not hard-code colours.
abstract final class AppColors {
  /// Portail BI green.
  static const green = Color(0xFFA5CF4B);

  /// Splash / launch screen background (always dark).
  static const splashBackground = Color(0xFF111318);

  /// Default `avatar_color` when the API sends none.
  static const avatarFallback = Color(0xFF358BA4);

  /// Colour of the local notification small icon / accent (#6E8F4F).
  static const notification = Color(0xFF6E8F4F);
}
