import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/group_logo.dart';

/// Home card of a pôle / société / module… group: fixed width, logo (or
/// code / initials) tile on top, group name underneath (2 lines max).
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.code,
    required this.name,
    required this.onTap,
    this.logoUrl,
  });

  final String code;
  final String name;
  final String? logoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HomeCard(
    name: name,
    onTap: onTap,
    tile: GroupLogo(
      label: (code.isEmpty ? name : code).toUpperCase(),
      logoUrl: logoUrl,
      assetCode: code,
      assetName: name,
    ),
  );
}

/// Consolidé direction card: code in bold in the tile, full direction name
/// small under it.
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
  Widget build(BuildContext context) => HomeCard(
    name: name,
    onTap: onTap,
    tile: GroupLogo(
      label: code.toUpperCase(),
      assetCode: code,
      assetName: name,
    ),
  );
}

/// Shared frame of the home cards (~88 wide, flat surface, 1px border).
class HomeCard extends StatelessWidget {
  const HomeCard({
    super.key,
    required this.tile,
    required this.name,
    required this.onTap,
  });

  final Widget tile;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: AppDimens.groupCardWidth,
      height: AppDimens.groupCardHeight,
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          side: BorderSide(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
            child: Column(
              children: [
                tile,
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
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
}
