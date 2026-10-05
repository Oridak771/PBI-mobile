import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/catalog.dart';

/// Tabs of the floating glass tab bar (and of the tablet rail).
enum ShellTab {
  home('Accueil'),
  favorites('Favoris'),
  tickets('Tickets'),
  profile('Profil');

  const ShellTab(this.title);
  final String title;
}

/// Group opened from the home screen (shown inside the shell, above the tab
/// bar). [initialTab] preselects a direction chip (consolidé cards); `null`
/// shows every report ("Tous").
class OpenGroup {
  const OpenGroup(this.group, {this.initialTab});
  final CatalogGroup group;
  final int? initialTab;
}

class ShellState {
  const ShellState({
    this.tab = ShellTab.home,
    this.group,
    this.notificationsRequested = false,
  });
  final ShellTab tab;
  final OpenGroup? group;

  /// The notifications screen must be opened (tap on a local notification,
  /// app started from one).
  final bool notificationsRequested;
}

class ShellController extends Notifier<ShellState> {
  @override
  ShellState build() => const ShellState();

  void selectTab(ShellTab tab) => state = ShellState(tab: tab);

  void openGroup(CatalogGroup group, {int? initialTab}) => state = ShellState(
    tab: ShellTab.home,
    group: OpenGroup(group, initialTab: initialTab),
  );

  void closeGroup() => state = ShellState(tab: state.tab);

  /// Asks the shell to open the notifications screen.
  void requestNotifications() => state = ShellState(
    tab: state.tab,
    group: state.group,
    notificationsRequested: true,
  );

  /// Called by the shell once the notifications screen is pushed.
  void notificationsShown() => state = ShellState(tab: state.tab, group: state.group);
}

final shellProvider = NotifierProvider<ShellController, ShellState>(
  ShellController.new,
);
