import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/common.dart';
import '../../data/models/catalog.dart';
import '../group_tabs/group_tabs_view.dart';
import '../reports/catalog_controller.dart';
import '../shell/shell_controller.dart';
import '../tickets/ticket_create_screen.dart';
import 'home_tiles.dart';

/// "Accueil": sections of the catalog, in order.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

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

    Future<void> refresh() => ref.read(catalogProvider.notifier).refresh();

    if (data.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(children: const [NoAccessMessage()]),
      );
    }

    // Skip rule: a single group → its tabs directly (no back arrow).
    final single = data.singleGroup;
    if (single != null) return GroupTabsView(group: single);

    return RefreshIndicator(
      onRefresh: refresh,
      color: AppColors.green,
      child: ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 10),
        children: [
          for (final (index, section) in data.sections.indexed)
            HomeSection(section: section, first: index == 0),
        ],
      ),
    );
  }
}

class HomeSection extends ConsumerWidget {
  const HomeSection({super.key, required this.section, required this.first});

  final CatalogSection section;
  final bool first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = ref.read(shellProvider.notifier);
    final Widget content;
    if (section.isConsolide) {
      final group = section.groups.first;
      content = SizedBox(
        height: AppDimens.consolideCardHeight + 12,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final (i, tab) in group.tabs.indexed)
              ConsolideCard(
                code: tab.code.isEmpty ? tab.name : tab.code,
                name: tab.name,
                onTap: () => shell.openGroup(group, initialTab: i),
              ),
          ],
        ),
      );
    } else if (section.layout == SectionLayout.grid) {
      final rows = AppDimens.societeGridRows(MediaQuery.sizeOf(context).width);
      content = SizedBox(
        height: rows * (AppDimens.tile + 10),
        child: GridView.count(
          scrollDirection: Axis.horizontal,
          crossAxisCount: rows,
          children: [
            for (final group in section.groups)
              GroupTile(
                code: group.code,
                name: group.name,
                onTap: () => shell.openGroup(group),
              ),
          ],
        ),
      );
    } else {
      content = SizedBox(
        height: AppDimens.tile + 10,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final group in section.groups)
              GroupTile(
                code: group.code,
                name: group.name,
                onTap: () => shell.openGroup(group),
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
            child: Text(
              section.title,
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          content,
        ],
      ),
    );
  }
}

/// Legacy "no privilege" state with the "Contacter" link.
class NoAccessMessage extends StatelessWidget {
  const NoAccessMessage({super.key});

  static const message =
      "Vous ne disposez d'aucun privilège. \n\n Pour plus d'informations "
      'veuillez contacter \n la cellule-BI.';

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 30),
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.tint, fontSize: 18),
          ),
        ),
        InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const TicketCreateScreen(
                initialType: 'access',
                initialTitle:
                    "Demande d'accès aux tableaux de bord de l'Application "
                    'Mobile CBI',
              ),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Contacter',
              style: TextStyle(
                color: AppColors.gray,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.gray,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
