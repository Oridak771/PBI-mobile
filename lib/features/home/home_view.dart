import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/layout/adaptive.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/skeleton.dart';
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
      return const HomeSkeleton();
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
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
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

  static const _padding = EdgeInsets.symmetric(horizontal: AppDimens.page);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = ref.read(shellProvider.notifier);
    final List<Widget> cards;
    if (section.isConsolide) {
      final group = section.groups.first;
      cards = [
        for (final (i, tab) in group.tabs.indexed)
          ConsolideCard(
            code: tab.code.isEmpty ? tab.name : tab.code,
            name: tab.name,
            onTap: () => shell.openGroup(group, initialTab: i),
          ),
      ];
    } else {
      cards = [for (final g in section.groups) _groupCard(g, shell)];
    }

    final Widget content;
    if (!context.windowSize.isCompact) {
      // Tablets: every card visible, wrapping; the column count follows the
      // width, the cards keep their size.
      content = Padding(
        padding: _padding,
        child: Wrap(
          key: ValueKey('home-wrap-${section.title}'),
          spacing: AppDimens.groupCardGap,
          runSpacing: AppDimens.groupCardGap,
          children: cards,
        ),
      );
    } else if (!section.isConsolide && section.layout == SectionLayout.grid) {
      final rows = AppDimens.societeGridRows(MediaQuery.sizeOf(context).width);
      content = SizedBox(
        height:
            rows * AppDimens.groupCardHeight +
            (rows - 1) * AppDimens.groupCardGap,
        child: GridView.builder(
          scrollDirection: Axis.horizontal,
          padding: _padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: rows,
            mainAxisSpacing: AppDimens.groupCardGap,
            crossAxisSpacing: AppDimens.groupCardGap,
            childAspectRatio:
                AppDimens.groupCardHeight / AppDimens.groupCardWidth,
          ),
          itemCount: cards.length,
          itemBuilder: (context, i) => cards[i],
        ),
      );
    } else {
      content = SizedBox(
        height: AppDimens.groupCardHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: _padding,
          itemCount: cards.length,
          separatorBuilder: (_, _) =>
              const SizedBox(width: AppDimens.groupCardGap),
          itemBuilder: (context, i) => cards[i],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          section.title,
          count: cards.length,
          padding: EdgeInsets.fromLTRB(
            AppDimens.page,
            first ? 8 : 20,
            AppDimens.page,
            10,
          ),
        ),
        content,
      ],
    );
  }

  static Widget _groupCard(CatalogGroup group, ShellController shell) =>
      GroupCard(
        code: group.code,
        name: group.name,
        logoUrl: group.logoUrl,
        onTap: () => shell.openGroup(group),
      );
}

/// Legacy "no privilege" state with the "Contacter" link.
class NoAccessMessage extends StatelessWidget {
  const NoAccessMessage({super.key});

  static const message =
      "Vous ne disposez d'aucun privilège. \n\n Pour plus d'informations "
      'veuillez contacter \n la cellule-BI.';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDimens.page, 48, AppDimens.page, 16),
      child: Column(
        children: [
          IconWell(Icons.lock_outline_rounded, size: 56),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 16, height: 1.35),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TicketCreateScreen(
                  initialType: 'access',
                  initialTitle:
                      "Demande d'accès aux tableaux de bord de l'Application "
                      'Mobile CBI',
                ),
              ),
            ),
            icon: Icon(Icons.mail_outline_rounded, color: palette.primaryText),
            label: const Text('Contacter'),
          ),
        ],
      ),
    );
  }
}
