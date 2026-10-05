import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/adaptive.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../favorites/favorites_screen.dart';
import '../group_tabs/group_tabs_view.dart';
import '../home/home_view.dart';
import '../notifications/local_notifications.dart';
import '../notifications/notifications_controller.dart';
import '../notifications/notifications_view.dart';
import '../reports/catalog_controller.dart';
import '../settings/settings_view.dart';
import 'shell_controller.dart';
import 'shell_header.dart';

/// Legacy HomeNavBarActivity: custom header, content, bottom navigation.
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen>
    with WidgetsBindingObserver {
  Timer? _poller;
  StreamSubscription<void>? _taps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final platform = ref.read(notificationPlatformProvider);
    _taps = platform.taps.listen((_) => _showNotificationsTab());
    platform.requestPermission().then((_) => platform.startBackgroundPolling());
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller?.cancel();
    _taps?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _poller?.cancel();
      _poller = null;
    }
  }

  /// Foreground badge polling every `config.notification_poll_seconds`.
  Future<void> _startPolling() async {
    _poller?.cancel();
    ref.read(unreadCountProvider.notifier).refresh();
    final config = await ref.read(remoteConfigProvider.future);
    if (!mounted) return;
    final seconds = config.notificationPollSeconds < 15
        ? 15
        : config.notificationPollSeconds;
    _poller?.cancel();
    _poller = Timer.periodic(
      Duration(seconds: seconds),
      (_) => ref.read(unreadCountProvider.notifier).refresh(),
    );
  }

  void _showNotificationsTab() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    ref.read(shellProvider.notifier).selectTab(ShellTab.notifications);
    ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final shell = ref.watch(shellProvider);
    final single = ref.watch(
      catalogProvider.select((c) => c.value?.singleGroup),
    );
    final unread = ref.watch(unreadCountProvider);
    final group = shell.group;

    final String title;
    VoidCallback? onBack;
    if (shell.tab == ShellTab.home && group != null) {
      title = group.group.name;
      onBack = ref.read(shellProvider.notifier).closeGroup;
    } else if (shell.tab == ShellTab.home && single != null) {
      title = single.name;
    } else {
      title = shell.tab.title;
    }

    final Widget body = switch (shell.tab) {
      ShellTab.home when group != null => GroupTabsView(
        key: ValueKey('group-${group.group.key}-${group.initialTab}'),
        group: group.group,
        initialTab: group.initialTab,
      ),
      ShellTab.home => const HomeView(),
      ShellTab.notifications => const NotificationsView(),
      ShellTab.favorites => const FavoritesView(),
      ShellTab.settings => const SettingsView(),
    };

    final palette = context.palette;
    void select(int i) {
      final tab = ShellTab.values[i];
      ref.read(shellProvider.notifier).selectTab(tab);
      if (tab == ShellTab.notifications) {
        ref.read(notificationsProvider.notifier).refresh();
      }
    }

    final compact = context.windowSize.isCompact;
    final content = SafeArea(
      bottom: false,
      left: compact,
      child: Column(
        children: [
          ShellHeader(title: title, onBack: onBack),
          Expanded(child: body),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Legacy: back does nothing on root tabs, closes the group tabs.
        if (!didPop && onBack != null) onBack();
      },
      child: Scaffold(
        body: compact
            ? content
            : Row(
                children: [
                  _ShellRail(
                    selectedIndex: shell.tab.index,
                    unread: unread,
                    onSelected: select,
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: palette.border),
                  Expanded(child: content),
                ],
              ),
        bottomNavigationBar: compact
            ? DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: palette.border)),
                ),
                child: NavigationBar(
                  selectedIndex: shell.tab.index,
                  onDestinationSelected: select,
                  destinations: [
                    for (final d in _destinations)
                      NavigationDestination(
                        icon: d.icon(unread, selected: false),
                        selectedIcon: d.icon(unread, selected: true),
                        label: d.label,
                      ),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}

/// Shell destinations, in legacy order (bottom bar and rail).
class _Destination {
  const _Destination(this.label, this.outlined, this.filled, {this.badge = false});

  final String label;
  final IconData outlined;
  final IconData filled;

  /// Shows the unread notifications badge.
  final bool badge;

  Widget icon(int unread, {required bool selected}) {
    final icon = Icon(selected ? filled : outlined);
    return badge ? _BadgeIcon(count: unread, child: icon) : icon;
  }
}

const _destinations = [
  _Destination('Accueil', Icons.home_outlined, Icons.home_rounded),
  _Destination(
    'Notification',
    Icons.notifications_outlined,
    Icons.notifications_rounded,
    badge: true,
  ),
  _Destination('Favoris', Icons.favorite_border_rounded, Icons.favorite_rounded),
  _Destination('Paramètre', Icons.settings_outlined, Icons.settings_rounded),
];

/// Medium / expanded windows: navigation rail with labels on the left.
class _ShellRail extends StatelessWidget {
  const _ShellRail({
    required this.selectedIndex,
    required this.unread,
    required this.onSelected,
  });

  final int selectedIndex;
  final int unread;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.palette.surface,
    child: SafeArea(
      right: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: NavigationRail(
                key: const Key('shell-rail'),
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelected,
                labelType: NavigationRailLabelType.all,
                groupAlignment: -0.85,
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: d.icon(unread, selected: false),
                      selectedIcon: d.icon(unread, selected: true),
                      label: Text(d.label),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Unread badge of the "Notification" destination.
class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) => Badge(
    key: const Key('notification-badge'),
    isLabelVisible: count > 0,
    backgroundColor: context.palette.danger,
    textColor: Colors.white,
    label: Text(count > 99 ? '99+' : '$count'),
    child: child,
  );
}
