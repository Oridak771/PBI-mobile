import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/layout/adaptive.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/catalog.dart';
import '../reports/catalog_controller.dart';
import '../reports/report_list.dart';

/// "Favoris" tab: favourite reports sorted by location then name.
class FavoritesView extends ConsumerWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final data = catalog.value;
    if (data == null) {
      if (catalog.hasError) {
        return Center(
          child: RetryMessage(
            message: errorMessage(catalog.error!),
            onRetry: () => ref.invalidate(catalogProvider),
          ),
        );
      }
      return const SkeletonList();
    }
    final favorites = data.favorites;
    return RefreshIndicator(
      onRefresh: () => ref.read(catalogProvider.notifier).refresh(),
      child: CenteredContent(
        builder: (context, gutter) => ListView(
        padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 24),
        children: [
          if (favorites.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyText(
                'Aucun rapport favoris',
                icon: Icons.favorite_border_rounded,
              ),
            )
          else ...[
            SectionHeader(
              'Rapports',
              count: favorites.length,
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
            ),
            for (final report in favorites)
              FavoriteRow(
                key: ValueKey(report.id),
                report: report,
                onTap: () => openReport(context, report),
                onRemove: () => toggleFavorite(context, ref, report.id),
              ),
          ],
        ],
      ),
      ),
    );
  }
}

/// Favourite row: same row as the report lists, location as subtitle.
class FavoriteRow extends StatelessWidget {
  const FavoriteRow({
    super.key,
    required this.report,
    required this.onTap,
    required this.onRemove,
  });

  final Report report;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => ReportRow(
    report: report,
    favorite: true,
    subtitle: report.location,
    onTap: onTap,
    onToggleFavorite: onRemove,
  );
}
