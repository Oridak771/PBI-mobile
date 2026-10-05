import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/layout/adaptive.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/catalog.dart';
import '../auth/session_controller.dart';
import '../group_tabs/group_tabs_view.dart';
import '../history/history_details_screen.dart';
import '../notifications/notifications_controller.dart';
import '../notifications/notifications_view.dart';
import '../reports/catalog_controller.dart';
import '../reports/report_list.dart';
import '../search/search_screen.dart';
import '../shell/shell_controller.dart';
import '../tickets/ticket_create_screen.dart';
import 'home_tiles.dart';
import 'recents_controller.dart';

/// Section shown by the home chip bar (`null` = the first one).
class HomeSectionController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String key) => state = key;
}

final homeSectionProvider = NotifierProvider<HomeSectionController, String?>(
  HomeSectionController.new,
);

/// "Accueil": greeting + bell, search field, "Récents", the catalog sections
/// as a blurred chip bar and the groups of the selected section as a grid.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final data = catalog.value;

    final Widget content;
    if (data == null) {
      content = catalog.hasError
          ? Center(
              child: SingleChildScrollView(
                child: RetryMessage(
                  message: errorMessage(catalog.error!),
                  onRetry: () => ref.invalidate(catalogProvider),
                ),
              ),
            )
          : const HomeSkeleton();
    } else if (data.isEmpty) {
      content = RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(children: const [NoAccessMessage()]),
      );
    } else if (data.singleGroup != null) {
      // Skip rule: a single group → its reports directly (no back button).
      content = GroupView(group: data.singleGroup!);
    } else {
      content = _HomeCatalog(catalog: data);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CenteredContent(
          builder: (context, gutter) => Padding(
            padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 0),
            child: const Column(
              children: [
                HomeHeader(),
                SizedBox(height: 14),
                HomeSearchField(),
              ],
            ),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }
}

Future<void> _refresh(WidgetRef ref) async {
  ref.invalidate(myHistoryProvider);
  await ref.read(catalogProvider.notifier).refresh();
}

/// Avatar (photo or green gradient initials), "Bonjour" + first name, bell.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final unread = ref.watch(unreadCountProvider);
    final name = (user?.name ?? '').trim();
    final firstName = name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
    return Row(
      children: [
        UserAvatar(
          size: 42,
          brand: true,
          photoUrl: user?.photoUrl,
          initials: user?.initials ?? '',
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour',
                style: TextStyle(color: palette.textMuted, fontSize: 11),
              ),
              Text(
                firstName,
                key: const Key('home-first-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          label: unread > 0 ? '$unread notifications non lues' : null,
          child: GlassIconButton(
            key: const Key('home-bell'),
            tooltip: 'Notifications',
            icon: Icons.notifications_none_rounded,
            iconSize: 21,
            onPressed: () => openNotifications(context, ref),
            badge: unread > 0
                ? GlowDot(
                    key: const Key('notification-badge'),
                    color: palette.primaryText,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Blurred glass field opening the report search.
class HomeSearchField extends StatelessWidget {
  const HomeSearchField({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: 'Rechercher un rapport',
      excludeSemantics: true,
      child: GlassPanel(
        key: const Key('home-search'),
        blur: true,
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
        ),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 18, color: palette.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rechercher un rapport',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textMuted, fontSize: 12.5),
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

class _HomeCatalog extends ConsumerWidget {
  const _HomeCatalog({required this.catalog});

  final Catalog catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = catalog.sections;
    final selectedKey = ref.watch(homeSectionProvider);
    final section = sections.firstWhere(
      (s) => s.key == selectedKey,
      orElse: () => sections.first,
    );
    final recents = recentReports(
      ref.watch(myHistoryProvider).value ?? const [],
      catalog,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final bottom = BottomBarInset.of(context);

    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = AdaptiveDimens.gutter(constraints.maxWidth);
          final inner = constraints.maxWidth - 2 * gutter;
          final columns = AppDimens.gridColumns(inner);
          final barHeight = 8 + 14 + scaler.scale(11.5) * 1.35 + 2;
          return CustomScrollView(
            key: const Key('home-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (recents.isNotEmpty)
                SliverToBoxAdapter(
                  child: _Recents(recents: recents, gutter: gutter),
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: 4)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _ChipBarDelegate(
                  height: barHeight + 28,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
                    child: GlassSegmentedBar<String>(
                      key: const Key('home-sections'),
                      segments: [
                        for (final s in sections)
                          GlassSegment(
                            s.key,
                            s.title,
                            key: Key('section-${s.key}'),
                          ),
                      ],
                      selected: {section.key},
                      onChanged: ref.read(homeSectionProvider.notifier).select,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 24 + bottom),
                sliver: _SectionGrid(
                  key: ValueKey('grid-${section.key}'),
                  catalog: catalog,
                  section: section,
                  columns: columns,
                  cardHeight: HomeCard.heightFor(scaler),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Recents extends StatelessWidget {
  const _Recents({required this.recents, required this.gutter});

  final List<RecentReport> recents;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Récents',
          padding: EdgeInsets.fromLTRB(gutter + 2, 16, gutter, 8),
          trailing: LinkText(
            'Tout voir',
            key: const Key('recents-all'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HistoryDetailsScreen(),
              ),
            ),
          ),
        ),
        SizedBox(
          height: RecentCard.heightFor(scaler),
          child: ListView.separated(
            key: const Key('recents'),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: gutter),
            itemCount: recents.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final r = recents[i];
              return RecentCard(
                key: ValueKey('recent-${r.report.id}'),
                report: r.report,
                location: r.item.location.isNotEmpty
                    ? r.item.location
                    : r.report.location,
                openedAt: r.item.openedAt,
                onTap: () => openReport(context, r.report),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChipBarDelegate extends SliverPersistentHeaderDelegate {
  _ChipBarDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      SizedBox(height: height, child: child);

  @override
  bool shouldRebuild(_ChipBarDelegate old) =>
      old.height != height || old.child != child;
}

/// Grid of the selected section: group cards, or the consolidé direction
/// cards (its single group's tabs).
class _SectionGrid extends ConsumerWidget {
  const _SectionGrid({
    super.key,
    required this.catalog,
    required this.section,
    required this.columns,
    required this.cardHeight,
  });

  final Catalog catalog;
  final CatalogSection section;
  final int columns;
  final double cardHeight;

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
            reportCount: catalog.reportCountOfTab(tab),
            onTap: () => shell.openGroup(group, initialTab: i),
          ),
      ];
    } else {
      cards = [
        for (final g in section.groups)
          GroupCard(
            code: g.code,
            name: g.name,
            logoUrl: g.logoUrl,
            reportCount: catalog.reportCountOf(g),
            onTap: () => shell.openGroup(g),
          ),
      ];
    }
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppDimens.gridGap,
        crossAxisSpacing: AppDimens.gridGap,
        mainAxisExtent: cardHeight,
      ),
      delegate: SliverChildListDelegate(cards),
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
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDimens.page, 32, AppDimens.page, 16),
      child: ContentWidth(
        maxWidth: 480,
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
          child: Column(
            children: [
              const IconWell(Icons.lock_outline_rounded, size: 56),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Contacter',
                icon: Icons.mail_outline_rounded,
                expand: false,
                height: 44,
                fontSize: 14,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TicketCreateScreen(
                      initialType: 'access',
                      initialTitle:
                          "Demande d'accès aux tableaux de bord de "
                          "l'Application Mobile CBI",
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
