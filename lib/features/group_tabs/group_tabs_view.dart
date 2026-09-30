import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/catalog.dart';
import '../reports/report_list.dart';

/// Legacy DirectionFragment: a tab per direction, each one a report list.
/// The tab bar is hidden when there is a single tab.
class GroupTabsView extends StatelessWidget {
  const GroupTabsView({super.key, required this.group, this.initialTab = 0});

  final CatalogGroup group;
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final tabs = group.tabs;
    if (tabs.isEmpty) return const SizedBox.shrink();
    if (tabs.length == 1) return ReportList(tab: tabs.single);
    return DefaultTabController(
      length: tabs.length,
      initialIndex: initialTab.clamp(0, tabs.length - 1),
      child: Column(
        children: [
          ColoredBox(
            color: AppColors.black,
            child: TabBar(
              isScrollable: tabs.length > 2,
              tabAlignment: tabs.length > 2 ? TabAlignment.start : TabAlignment.fill,
              labelColor: AppColors.blueGreen,
              unselectedLabelColor: AppColors.gray,
              indicatorColor: AppColors.accent,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              tabs: [for (final tab in tabs) Tab(text: tab.label)],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [for (final tab in tabs) ReportList(tab: tab)],
            ),
          ),
        ],
      ),
    );
  }
}
