import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/asset_slots.dart';

/// Legacy item_consolide.xml: 60x80 card, image slot on top, code below.
class ConsolideCard extends StatelessWidget {
  const ConsolideCard({
    super.key,
    required this.code,
    required this.name,
    required this.onTap,
  });

  final String code;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(6),
    child: Material(
      color: AppColors.gray,
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: AppDimens.consolideCardWidth,
          height: AppDimens.consolideCardHeight,
          child: Column(
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: CodeImageSlot(
                    asset: AppAssets.forCode(code, name: name),
                    fallback: const SizedBox.shrink(),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      code.toUpperCase(),
                      maxLines: 1,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: AppShadows.white335,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Legacy item_img_text.xml: 70x70 tile, image (centerCrop) or code text.
class GroupTile extends StatelessWidget {
  const GroupTile({
    super.key,
    required this.code,
    required this.name,
    required this.onTap,
  });

  final String code;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final asset = AppAssets.forCode(code, name: name);
    final label = (code.isEmpty ? name : code).toUpperCase();
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Material(
        color: AppColors.gray,
        elevation: 2,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: AppDimens.tile,
            height: AppDimens.tile,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: CodeImageSlot(
                asset: asset,
                fit: BoxFit.cover,
                fallback: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.blueGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: AppShadows.white335,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
