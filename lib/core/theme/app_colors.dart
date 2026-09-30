import 'package:flutter/material.dart';

/// Colour palette of the legacy GSH - CBI app (res/values/colors.xml).
abstract final class AppColors {
  static const primary = Color(0xFF2C2C2C);
  static const primaryDark = Color(0xFF1D1D1D);
  static const accent = Color(0xFF6F6F6F);

  static const green = Color(0xFFA5CF4B);
  static const greenLight = Color(0x66A5CF4B);

  /// Main background.
  static const black = Color(0xFF1C1D22);

  /// Menu / card surface.
  static const surface = Color(0xFF2F3139);
  static const gray = Color(0xFFF2F2F2);
  static const tint = Color(0xFFD2D2D2);
  static const blue = Color(0xFF0099D5);
  static const blueGreen = Color(0xFF358BA4);

  /// Settings sheet / legacy dialogs background.
  static const sheet = Color(0xFFF1F1F1);

  /// Table header / grey text.
  static const greyText = Color(0xFFABABAB);
  static const red = Color(0xFFC24157);
  static const yellow = Color(0xFFFFC34A);
  static const loginHint = Color(0x57E6E6E6);
  static const textShadow = Color(0x4F141414);
  static const textShadowWhite = Color(0x4FC9C9C9);
  static const disabledButtonText = Color(0xB21C1D22);

  /// Legacy dialog title / button text.
  static const dialogText = Color(0xFFE9E9E9);
  static const white = Color(0xFFFFFFFF);

  /// Colour of the local notification small icon / accent (#6E8F4F).
  static const notification = Color(0xFF6E8F4F);
}
