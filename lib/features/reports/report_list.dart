import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/report_tile.dart';
import '../../data/models/catalog.dart';
import '../viewer/viewer_screen.dart';
import 'catalog_controller.dart';

/// Opens the report viewer.
void openReport(BuildContext context, Report report) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ViewerScreen(report: report)),
  );
}

/// Toggles a favourite and shows the error (after rollback) if any.
Future<void> toggleFavorite(
  BuildContext context,
  WidgetRef ref,
  int reportId,
) async {
  final error = await ref.read(catalogProvider.notifier).toggleFavorite(reportId);
  if (error != null && context.mounted) showToast(context, error);
}

/// Meta line of a report row: "Vue mobile · DCO" (with a phone icon) when
/// the report has a mobile view, otherwise "DFC · mis à jour hier" (or just
/// the label when the modification date is unknown).
({bool mobile, String text}) reportMeta(
  Report report,
  String label, {
  DateTime? now,
}) {
  if (report.hasMobileView) {
    return (
      mobile: true,
      text: label.isEmpty ? 'Vue mobile' : 'Vue mobile · $label',
    );
  }
  final modified = relativeShortFr(report.modifiedAt, now: now);
  final parts = [
    if (label.isNotEmpty) label,
    if (modified.isNotEmpty)
      modified == 'hier' || modified.startsWith('à ')
          ? 'mis à jour $modified'
          : 'mis à jour il y a $modified',
  ];
  return (mobile: false, text: parts.join(' · '));
}

/// Last segment of a `location` ("Consolidé / DFC" → "DFC").
String locationLabel(String location) {
  final parts = location.split('/').map((p) => p.trim()).where((p) => p.isNotEmpty);
  return parts.isEmpty ? '' : parts.last;
}

/// Report row of the glass list panels: icon tile, name, meta line, heart.
class ReportRow extends StatelessWidget {
  const ReportRow({
    super.key,
    required this.report,
    required this.favorite,
    required this.onTap,
    required this.onToggleFavorite,
    this.label = '',
  });

  final Report report;
  final bool favorite;

  /// Direction code / location label of the meta line.
  final String label;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final meta = reportMeta(report, label);
    final metaStyle = TextStyle(color: palette.textMuted, fontSize: 10.5);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppDimens.reportRowMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            children: [
              ReportIconTile(name: report.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (meta.text.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (meta.mobile) ...[
                            Icon(
                              Icons.smartphone_rounded,
                              key: const Key('report-mobile-icon'),
                              size: 11,
                              color: palette.textMuted,
                              semanticLabel: 'Vue mobile disponible',
                            ),
                            const SizedBox(width: 3),
                          ],
                          Expanded(
                            child: Text(
                              meta.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: metaStyle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              FavoriteHeart(favorite: favorite, onPressed: onToggleFavorite),
            ],
          ),
        ),
      ),
    );
  }
}

/// One glass list panel of report rows (`(report, label)` entries).
class ReportListPanel extends ConsumerWidget {
  const ReportListPanel({super.key, required this.entries});

  final List<(Report, String)> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider).value;
    return GlassListPanel(
      key: const Key('report-list-panel'),
      children: [
        for (final (report, label) in entries)
          ReportRow(
            key: ValueKey('report-${report.id}'),
            report: report,
            label: label,
            favorite: catalog?.isFavorite(report.id) ?? report.favorite,
            onTap: () => openReport(context, report),
            onToggleFavorite: () => toggleFavorite(context, ref, report.id),
          ),
      ],
    );
  }
}
