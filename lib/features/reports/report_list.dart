import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/adaptive.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/skeleton.dart';
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

/// Legacy fragment_list_rapport.xml: report rows of one tab.
class ReportList extends ConsumerWidget {
  const ReportList({super.key, required this.tab});

  final GroupTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider).value;
    if (catalog == null) return const SkeletonList();
    final reports = catalog.reportsFor(tab);
    return RefreshIndicator(
      onRefresh: () => ref.read(catalogProvider.notifier).refresh(),
      child: CenteredContent(
        builder: (context, gutter) => ListView.builder(
        padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 24),
        itemCount: reports.length,
        itemBuilder: (context, i) {
          final report = reports[i];
          return ReportRow(
            key: ValueKey(report.id),
            report: report,
            subtitle: report.description.isNotEmpty
                ? report.description
                : report.location,
            favorite: catalog.isFavorite(report.id),
            onTap: () => openReport(context, report),
            onToggleFavorite: () => toggleFavorite(context, ref, report.id),
          );
        },
      ),
      ),
    );
  }
}

/// Report row: leading insights icon well, name, muted subtitle, heart.
class ReportRow extends StatelessWidget {
  const ReportRow({
    super.key,
    required this.report,
    required this.favorite,
    required this.onTap,
    required this.onToggleFavorite,
    this.subtitle,
  });

  final Report report;
  final bool favorite;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sub = subtitle ?? '';
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppDimens.reportRowMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              const IconWell(Icons.insights_rounded),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                    if (sub.isNotEmpty || report.hasPhoneEdition) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (report.hasPhoneEdition) ...[
                            Icon(
                              Icons.smartphone_rounded,
                              size: 13,
                              color: palette.primaryText,
                              semanticLabel: 'Édition téléphone',
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textMuted,
                                fontSize: 13,
                              ),
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
