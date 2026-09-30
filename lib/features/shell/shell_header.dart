import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/asset_slots.dart';

/// Legacy home_nav_bar_act.xml header (65 high, padding 5): optional back
/// arrow, 30sp green title, 4-line "staircase" decoration, small GSH logo.
class ShellHeader extends StatelessWidget {
  const ShellHeader({
    super.key,
    required this.title,
    this.onBack,
  });

  final String title;

  /// Shows the back arrow when not null (inside group tabs only).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Container(
    height: 65,
    padding: const EdgeInsets.all(5),
    child: LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onBack != null)
            InkWell(
              key: const Key('shell-back'),
              onTap: onBack,
              child: const Icon(
                Icons.chevron_left,
                size: 30,
                color: AppColors.blueGreen,
                semanticLabel: 'Retour',
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.62),
            child: Padding(
              padding: const EdgeInsets.only(left: 5, top: 5),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ),
          ),
          const Expanded(child: HeaderStaircase()),
          Container(
            width: 60,
            margin: const EdgeInsets.only(right: 2),
            padding: const EdgeInsets.fromLTRB(5, 2, 3, 8),
            child: const LogoSlot(
              asset: AppAssets.headerLogo,
              fallbackText: 'GSH',
              fontSize: 20,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Four 2px `#66A5CF4B` lines, 3 apart, indented 5/10/15/20.
class HeaderStaircase extends StatelessWidget {
  const HeaderStaircase({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, left: 10, right: 10),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            height: 2,
            margin: EdgeInsets.only(left: 5.0 * (i + 1), top: i == 0 ? 0 : 3),
            color: AppColors.greenLight,
          ),
      ],
    ),
  );
}
