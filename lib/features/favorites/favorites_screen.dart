import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/layout/adaptive.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/catalog.dart';
import '../reports/catalog_controller.dart';
import '../reports/report_list.dart';
import '../shell/shell_header.dart';

/// Favourite reports grouped by location (already sorted by location then
/// name), in order of first appearance.
List<(String, List<Report>)> favoritesByLocation(List<Report> favorites) {
  final groups = <String, List<Report>>{};
  for (final r in favorites) {
    groups.putIfAbsent(r.location, () => []).add(r);
  }
  return [for (final e in groups.entries) (e.key, e.value)];
}

/// "Favoris" tab: glass list panels of favourite reports, one per location.
class FavoritesView extends ConsumerWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final data = catalog.value;
    final Widget body;
    if (data == null) {
      body = catalog.hasError
          ? Center(
              child: SingleChildScrollView(
                child: RetryMessage(
                  message: errorMessage(catalog.error!),
                  onRetry: () => ref.invalidate(catalogProvider),
                ),
              ),
            )
          : const SkeletonList();
    } else {
      final groups = favoritesByLocation(data.favorites);
      final bottom = BottomBarInset.of(context);
      body = RefreshIndicator(
        onRefresh: () => ref.read(catalogProvider.notifier).refresh(),
        child: CenteredContent(
          builder: (context, gutter) => ListView(
            key: const Key('favorites-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 24 + bottom),
            children: [
              if (groups.isEmpty)
                const _EmptyFavorites()
              else
                for (final (location, reports) in groups) ...[
                  SectionHeader(
                    location.isEmpty ? 'Rapports' : location,
                    count: reports.length,
                    padding: const EdgeInsets.fromLTRB(4, 14, 2, 8),
                  ),
                  ReportListPanel(entries: [for (final r in reports) (r, '')]),
                ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ShellHeader(title: 'Favoris'),
        Expanded(child: body),
      ],
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        child: Column(
          children: [
            const IconWell(Icons.favorite_border_rounded, size: 52),
            const SizedBox(height: 14),
            Text(
              'Aucun rapport favoris',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Touchez le cœur d’un rapport pour le retrouver ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
