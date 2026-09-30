import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/common.dart';
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
    if (catalog == null) return const Center(child: CircularProgressIndicator());
    final reports = catalog.reportsFor(tab);
    return RefreshIndicator(
      onRefresh: () => ref.read(catalogProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 15, bottom: 10),
        itemCount: reports.length,
        itemBuilder: (context, i) {
          final report = reports[i];
          return ReportRow(
            report: report,
            favorite: catalog.isFavorite(report.id),
            onTap: () => openReport(context, report),
            onToggleFavorite: () => toggleFavorite(context, ref, report.id),
          );
        },
      ),
    );
  }
}

/// Legacy row_item_rapport.xml.
class ReportRow extends StatelessWidget {
  const ReportRow({
    super.key,
    required this.report,
    required this.favorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final Report report;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppDimens.reportRowHeight,
    child: Card(
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Text(
                    report.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.gray,
                      fontSize: 18,
                      height: 1.15,
                      shadows: AppShadows.dark335,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(5),
                child: FavoriteHeart(
                  favorite: favorite,
                  onPressed: onToggleFavorite,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
