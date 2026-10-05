import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/adaptive.dart';
import '../../core/providers.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/glass.dart';
import '../favorites/favorites_screen.dart';
import '../group_tabs/group_tabs_view.dart';
import '../home/home_view.dart';
import '../notifications/local_notifications.dart';
import '../notifications/notifications_controller.dart';
import '../notifications/notifications_view.dart';
import '../settings/settings_view.dart';
import '../tickets/tickets_screen.dart';
import 'shell_controller.dart';

/// Main screen: the current tab on the glass background, a floating glass
/// tab bar on phones (Accueil / Favoris / Tickets / Profil) or a glass
/// navigation rail on tablets. Notifications open from Accueil's bell.
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
    _taps = platform.taps.listen((_) => _showNotifications());
    platform.requestPermission().then((_) => platform.startBackgroundPolling());
    _startPolling();
    // Started from a notification (see SplashScreen).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(shellProvider).notificationsRequested) {
        _showNotifications();
      }
    });
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

  void _showNotifications() {
    if (!mounted) return;
    ref.read(shellProvider.notifier).notificationsShown();
    Navigator.of(context).popUntil((route) => route.isFirst);
    ref.invalidate(notificationsProvider);
    openNotifications(context, ref, refresh: false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shellProvider.select((s) => s.notificationsRequested), (
      _,
      requested,
    ) {
      if (requested) _showNotifications();
    });
    final shell = ref.watch(shellProvider);
    final group = shell.group;
    final closeGroup = ref.read(shellProvider.notifier).closeGroup;
    final onBack = shell.tab == ShellTab.home && group != null
        ? closeGroup
        : null;

    final Widget body = switch (shell.tab) {
      ShellTab.home when group != null => GroupView(
        key: ValueKey('group-${group.group.key}-${group.initialTab}'),
        group: group.group,
        initialTab: group.initialTab,
        onBack: closeGroup,
      ),
      ShellTab.home => const HomeView(),
      ShellTab.favorites => const FavoritesView(),
      ShellTab.tickets => const TicketsScreen(inShell: true),
      ShellTab.profile => const SettingsView(),
    };

    void select(int i) =>
        ref.read(shellProvider.notifier).selectTab(ShellTab.values[i]);

    final compact = context.windowSize.isCompact;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final Widget content;
    if (compact) {
      content = Stack(
        children: [
          Positioned.fill(
            child: BottomBarInset(
              value: AppDimens.tabBarReserve + bottom,
              child: SafeArea(bottom: false, child: body),
            ),
          ),
          Positioned(
            left: AppDimens.tabBarSide,
            right: AppDimens.tabBarSide,
            bottom: AppDimens.tabBarBottom + bottom,
            child: GlassTabBar(selected: shell.tab, onSelected: select),
          ),
        ],
      );
    } else {
      content = Row(
        children: [
          _ShellRail(selectedIndex: shell.tab.index, onSelected: select),
          Expanded(
            child: SafeArea(left: false, bottom: false, child: body),
          ),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Legacy: back does nothing on root tabs, closes the group.
        if (!didPop && onBack != null) onBack();
      },
      child: GlassScaffold(body: content),
    );
  }
}

/// Destinations, in tab order (tab bar and rail).
class _Destination {
  const _Destination(this.label, this.outlined, this.filled);

  final String label;
  final IconData outlined;
  final IconData filled;
}

const _destinations = [
  _Destination('Accueil', Icons.home_outlined, Icons.home_rounded),
  _Destination('Favoris', Icons.favorite_border_rounded, Icons.favorite_rounded),
  _Destination(
    'Tickets',
    Icons.confirmation_number_outlined,
    Icons.confirmation_number_rounded,
  ),
  _Destination('Profil', Icons.person_outline_rounded, Icons.person_rounded),
];

/// Floating blurred glass tab bar (64 high, radius 32); the selected tab is
/// a lit glass pill with a green icon and label.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key = const Key('glass-tab-bar'),
    required this.selected,
    required this.onSelected,
  });

  final ShellTab selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => GlassPanel(
    blur: true,
    height: AppDimens.tabBarHeight,
    borderRadius: BorderRadius.circular(AppDimens.tabBarHeight / 2),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final (i, d) in _destinations.indexed)
          Flexible(
            child: _TabItem(
              key: Key('tab-${ShellTab.values[i].name}'),
              destination: d,
              selected: selected.index == i,
              onTap: () => onSelected(i),
            ),
          ),
      ],
    ),
  );
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  static const _radius = BorderRadius.all(Radius.circular(26));

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected
        ? palette.primaryBright
        : palette.text.withValues(alpha: palette.isDark ? 0.7 : 0.62);
    final item = SizedBox(
      width: 68,
      height: 52,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? destination.filled : destination.outlined,
            size: 21,
            color: color,
          ),
          const SizedBox(height: 2),
          Text(
            destination.label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            // The bar keeps its height with large fonts.
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: 1.1),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: GlassPanel(
        borderRadius: _radius,
        // Lit pill (white 12% + inner highlight) only when selected.
        fill: selected ? palette.glassSelected : Colors.transparent,
        borderColor: Colors.transparent,
        shadow: false,
        highlight: selected,
        onTap: onTap,
        child: item,
      ),
    );
  }
}

/// Medium / expanded windows: navigation rail with labels in a floating glass
/// panel on the left.
class _ShellRail extends StatelessWidget {
  const _ShellRail({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    right: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: GlassPanel(
        blur: true,
        borderRadius: BorderRadius.circular(28),
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
                        icon: Icon(d.outlined),
                        selectedIcon: Icon(d.filled),
                        label: Text(d.label),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
