import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Legacy: back does nothing on root tabs, closes the group tabs.
        if (!didPop && onBack != null) onBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ShellHeader(title: title, onBack: onBack),
              Expanded(child: body),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.green,
          unselectedItemColor: AppColors.white,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          currentIndex: shell.tab.index,
          onTap: (i) {
            final tab = ShellTab.values[i];
            ref.read(shellProvider.notifier).selectTab(tab);
            if (tab == ShellTab.notifications) {
              ref.read(notificationsProvider.notifier).refresh();
            }
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                key: const Key('notification-badge'),
                isLabelVisible: unread > 0,
                backgroundColor: AppColors.red,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: const Icon(Icons.notifications),
              ),
              label: 'Notification',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Favoris',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.menu),
              label: 'Paramètre',
            ),
          ],
        ),
      ),
    );
  }
}
