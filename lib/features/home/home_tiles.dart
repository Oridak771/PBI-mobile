import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/group_logo.dart';
import '../../core/widgets/report_tile.dart';
import '../../data/models/catalog.dart';

/// "N rapports".
String reportCountLabel(int count) => count == 1 ? '1 rapport' : '$count rapports';

/// Home card of a pôle / société / module… group: logo (white rounded
/// square, or the code on a green tint), name, "N rapports".
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.code,
    required this.name,
    required this.reportCount,
    required this.onTap,
    this.logoUrl,
  });

  final String code;
  final String name;
  final String? logoUrl;
  final int reportCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HomeCard(
    name: name,
    subtitle: reportCountLabel(reportCount),
    onTap: onTap,
    tile: GroupLogo(
      label: (code.isEmpty ? name : code).toUpperCase(),
      logoUrl: logoUrl,
      assetCode: code,
      assetName: name,
    ),
  );
}

/// Consolidé direction card: the direction code on the tile, the direction
/// name and its report count under it.
class ConsolideCard extends StatelessWidget {
  const ConsolideCard({
    super.key,
    required this.code,
    required this.name,
    required this.reportCount,
    required this.onTap,
  });

  final String code;
  final String name;
  final int reportCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HomeCard(
    name: name,
    subtitle: reportCountLabel(reportCount),
    onTap: onTap,
    tile: GroupLogo(
      label: code.toUpperCase(),
      assetCode: code,
      assetName: name,
    ),
  );
}

/// Shared glass frame of the home grid cards (centered column).
class HomeCard extends StatelessWidget {
  const HomeCard({
    super.key,
    required this.tile,
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  final Widget tile;
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  /// Card height for the current text scale (logo, 2 name lines, count).
  static double heightFor(TextScaler scaler) =>
      22 + AppDimens.groupLogo + 7 + scaler.scale(11.5) * 1.25 * 2 +
      scaler.scale(9.5) * 1.35 + 2;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(6, 11, 6, 11),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tile,
            const SizedBox(height: 7),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.text,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textMuted, fontSize: 9.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Récents" card: icon tile, report name, "location · il y a 2 h".
class RecentCard extends StatelessWidget {
  const RecentCard({
    super.key,
    required this.report,
    required this.location,
    required this.openedAt,
    required this.onTap,
  });

  final Report report;
  final String location;
  final DateTime? openedAt;
  final VoidCallback onTap;

  static const width = 156.0;

  static double heightFor(TextScaler scaler) =>
      26 + AppDimens.tile + 10 + scaler.scale(12.5) * 1.25 * 2 + 3 +
      scaler.scale(10) * 1.35 + 2;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final when = relativeAgoFr(openedAt);
    final meta = [if (location.isNotEmpty) location, if (when.isNotEmpty) when];
    return SizedBox(
      width: width,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReportIconTile(name: report.name),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                report.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              meta.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
