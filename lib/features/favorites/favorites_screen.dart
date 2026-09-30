import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
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
      return const Center(child: CircularProgressIndicator());
    }
    final favorites = data.favorites;
    return RefreshIndicator(
      onRefresh: () => ref.read(catalogProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 10),
        children: [
          if (favorites.isEmpty)
            const EmptyText('Aucun rapport favoris')
          else
            for (final report in favorites)
              FavoriteRow(
                key: ValueKey(report.id),
                report: report,
                onTap: () => openReport(context, report),
                onRemove: () => toggleFavorite(context, ref, report.id),
              ),
        ],
      ),
    );
  }
}

/// Legacy row_item_rapport_favoris.xml.
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
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 5, right: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(5),
                    child: Text(
                      report.location,
                      style: const TextStyle(
                        color: AppColors.greyText,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: AppColors.greyText,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(5, 5, 5, 10),
                    child: Text(
                      report.name,
                      style: const TextStyle(
                        color: AppColors.gray,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FavoriteHeart(favorite: true, onPressed: onRemove),
          ],
        ),
      ),
    ),
  );
}
