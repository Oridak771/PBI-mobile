import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/adaptive.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/group_logo.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/catalog.dart';
import '../reports/catalog_controller.dart';
import '../reports/report_list.dart';

/// Group screen (société / pôle / direction…, legacy DirectionFragment):
/// header (round back button, logo, name, "parent · N rapports"), "Tous" +
/// direction chips filtering the reports, and the reports in one glass list
/// panel.
class GroupView extends ConsumerStatefulWidget {
  const GroupView({
    super.key,
    required this.group,
    this.initialTab,
    this.onBack,
  });

  final CatalogGroup group;

  /// Preselected direction chip; `null` = "Tous".
  final int? initialTab;

  /// Shows the back button when not null.
  final VoidCallback? onBack;

  @override
  ConsumerState<GroupView> createState() => _GroupViewState();
}

class _GroupViewState extends ConsumerState<GroupView> {
  /// Selected tab index, `null` = "Tous".
  late int? _tab = _initial();

  int? _initial() {
    final tabs = widget.group.tabs;
    final i = widget.initialTab;
    if (tabs.length <= 1 || i == null) return null;
    return i.clamp(0, tabs.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider).value;
    final group = widget.group;
    final tabs = group.tabs;
    if (catalog == null) return const SkeletonList();

    final all = catalog.reportsOfGroup(group);
    final selected = _tab;
    final entries = selected == null
        ? [for (final (r, tab) in all) (r, tab.label)]
        : [
            for (final r in catalog.reportsFor(tabs[selected]))
              (r, tabs[selected].label),
          ];
    final parent = group.parent ?? catalog.sectionOf(group)?.title ?? '';
    final count = all.length;
    final subtitle = [
      if (parent.isNotEmpty && parent != group.name) parent,
      count == 1 ? '1 rapport' : '$count rapports',
    ].join(' · ');
    final bottom = BottomBarInset.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CenteredContent(
          builder: (context, gutter) => Padding(
            padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 0),
            child: GroupHeader(
              group: group,
              subtitle: subtitle,
              onBack: widget.onBack,
            ),
          ),
        ),
        if (tabs.length > 1)
          CenteredContent(
            builder: (context, gutter) => SingleChildScrollView(
              key: const Key('group-chips'),
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
              child: Row(
                children: [
                  GlassChip(
                    key: const Key('group-chip-all'),
                    label: 'Tous',
                    standalone: true,
                    selected: selected == null,
                    onTap: () => setState(() => _tab = null),
                  ),
                  for (final (i, tab) in tabs.indexed) ...[
                    const SizedBox(width: 6),
                    GlassChip(
                      key: Key('group-chip-$i'),
                      label: tab.label,
                      standalone: true,
                      selected: selected == i,
                      onTap: () => setState(() => _tab = i),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(catalogProvider.notifier).refresh(),
            child: CenteredContent(
              builder: (context, gutter) => ListView(
                key: const Key('group-reports'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 24 + bottom),
                children: [
                  if (entries.isEmpty)
                    const EmptyText(
                      'Aucun rapport',
                      icon: Icons.insert_chart_outlined_rounded,
                    )
                  else
                    ReportListPanel(entries: entries),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Logo + name + subtitle, with the round glass back button.
class GroupHeader extends StatelessWidget {
  const GroupHeader({
    super.key,
    required this.group,
    required this.subtitle,
    this.onBack,
  });

  final CatalogGroup group;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        if (onBack != null) ...[
          GlassIconButton(
            key: const Key('shell-back'),
            tooltip: 'Retour',
            size: 40,
            icon: Icons.chevron_left_rounded,
            iconSize: 24,
            onPressed: onBack,
          ),
          const SizedBox(width: 12),
        ],
        GroupLogo(
          label: group.label,
          logoUrl: group.logoUrl,
          assetCode: group.code,
          assetName: group.name,
          size: AppDimens.tile,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
