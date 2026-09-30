import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/catalog.dart';

/// Bottom-navigation tabs, in legacy order.
enum ShellTab {
  home('Accueil'),
  notifications('Notification'),
  favorites('Favoris'),
  settings('Paramètre');

  const ShellTab(this.title);
  final String title;
}

/// Group opened from the home screen (legacy DirectionFragment shown inside
/// the shell, under the same header and above the bottom navigation).
class OpenGroup {
  const OpenGroup(this.group, {this.initialTab = 0});
  final CatalogGroup group;
  final int initialTab;
}

class ShellState {
  const ShellState({this.tab = ShellTab.home, this.group});
  final ShellTab tab;
  final OpenGroup? group;
}

class ShellController extends Notifier<ShellState> {
  @override
  ShellState build() => const ShellState();

  void selectTab(ShellTab tab) => state = ShellState(tab: tab);

  void openGroup(CatalogGroup group, {int initialTab = 0}) => state =
      ShellState(tab: ShellTab.home, group: OpenGroup(group, initialTab: initialTab));

  void closeGroup() => state = ShellState(tab: state.tab);
}

final shellProvider = NotifierProvider<ShellController, ShellState>(
  ShellController.new,
);
