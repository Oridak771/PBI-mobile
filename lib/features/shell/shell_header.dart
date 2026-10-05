import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/asset_slots.dart';

/// App bar area of the shell: optional green back arrow (inside group tabs),
/// bold title in the text colour with a small green dot on root tabs, and
/// the Portail BI mark on the right (theme-aware).
class ShellHeader extends StatelessWidget {
  const ShellHeader({super.key, required this.title, this.onBack});

  final String title;

  /// Shows the back arrow when not null (inside group tabs only).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      height: AppDimens.shellHeaderHeight,
      child: Padding(
        padding: EdgeInsets.only(
          left: onBack == null ? AppDimens.page : 4,
          right: AppDimens.page - 4,
        ),
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                key: const Key('shell-back'),
                tooltip: 'Retour',
                onPressed: onBack,
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: palette.primaryText,
                  semanticLabel: 'Retour',
                ),
              )
            else
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10, top: 2),
                decoration: BoxDecoration(
                  color: palette.primary,
                  shape: BoxShape.circle,
                ),
              ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.text,
                  fontSize: onBack == null ? 26 : 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 36,
              height: 36,
              child: LogoSlot(
                asset: AppAssets.headerLogo(brightness),
                fallbackText: 'GSH',
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
