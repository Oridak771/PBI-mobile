import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Shows [asset] when registered in `AppAssets`, otherwise a styled text logo
/// ("GSH" / "CBI") – the pending-assets fallback.
class LogoSlot extends StatelessWidget {
  const LogoSlot({
    super.key,
    required this.asset,
    required this.fallbackText,
    this.fontSize = 48,
    this.color,
    this.accentColor,
    this.fit = BoxFit.contain,
  });

  final String? asset;
  final String fallbackText;
  final double fontSize;
  /// Fallback text colour (defaults to the palette text colour).
  final Color? color;

  /// Fallback underline colour (defaults to the brand green).
  final Color? accentColor;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final path = asset;
    final palette = context.palette;
    final fallback = _TextLogo(
      text: fallbackText,
      fontSize: fontSize,
      color: color ?? palette.text,
      accentColor: accentColor ?? palette.primary,
    );
    if (path == null) return fallback;
    return Image.asset(
      path,
      fit: fit,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _TextLogo extends StatelessWidget {
  const _TextLogo({
    required this.text,
    required this.fontSize,
    required this.color,
    required this.accentColor,
  });

  final String text;
  final double fontSize;
  final Color color;
  final Color accentColor;

  @override
  Widget build(BuildContext context) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: fontSize * 0.12,
              height: 1,
            ),
          ),
          SizedBox(height: fontSize * 0.08),
          Container(
            width: fontSize * text.length * 0.7,
            height: (fontSize * 0.08).clamp(2, 6),
            color: accentColor,
          ),
        ],
      ),
    ),
  );
}
