import 'package:cbi_mobile/core/widgets/glass.dart';
import 'package:cbi_mobile/features/group_tabs/group_tabs_view.dart';
import 'package:cbi_mobile/features/home/home_view.dart';
import 'package:cbi_mobile/features/notifications/notifications_view.dart';
import 'package:cbi_mobile/features/settings/settings_view.dart';
import 'package:cbi_mobile/features/shell/shell_screen.dart';
import 'package:cbi_mobile/features/tickets/tickets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('shell: glass tab bar, bell → notifications, group chips', (
    tester,
  ) async {
    // Phone width: floating glass tab bar (compact window).
    setWindowSize(tester, const Size(412, 900));
    await tester.pumpWidget(
      testApp(const ShellScreen(), repo: FakeRepository(), scaffold: false),
    );
    await tester.pumpAndSettle();

    // Painted once behind the screen.
    expect(find.byType(GlassBackground), findsOneWidget);
    expect(find.byType(HomeView), findsOneWidget);
    expect(find.byKey(const Key('shell-back')), findsNothing);

    // Four tabs in order, in the floating tab bar (16 from the sides).
    final bar = find.byType(GlassTabBar);
    expect(bar, findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    final rect = tester.getRect(bar);
    expect(rect.left, 16);
    expect(rect.right, 412 - 16);
    expect(rect.height, 64);
    expect(900 - rect.bottom, 18);
    final labels = ['Accueil', 'Favoris', 'Tickets', 'Profil'];
    final x = <double>[];
    for (final label in labels) {
      final finder = find.descendant(of: bar, matching: find.text(label));
      expect(finder, findsOneWidget);
      x.add(tester.getCenter(finder).dx);
    }
    expect(x, orderedEquals([...x]..sort()));
    expect(find.descendant(of: bar, matching: find.text('Notification')), findsNothing);

    // Unread dot on the bell; the bell opens the notifications screen.
    expect(find.byKey(const Key('notification-badge')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-bell')));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsNothing);

    // Open a pôle group: header (back, name, subtitle), "Tous" + codes.
    await tester.tap(find.text('Pôle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PC'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupView), findsOneWidget);
    expect(find.text('Pôle Construction'), findsOneWidget);
    expect(find.text('Pôle · 2 rapports'), findsOneWidget);
    expect(find.byKey(const Key('shell-back')), findsOneWidget);
    expect(find.byType(Tab), findsNothing);
    for (final chip in ['Tous', 'DFC', 'DCO']) {
      expect(
        find.descendant(
          of: find.byKey(const Key('group-chips')),
          matching: find.text(chip),
        ),
        findsOneWidget,
      );
    }
    // "Tous": every report, in one glass list panel.
    expect(find.text('Trésorerie Pôle Construction'), findsOneWidget);
    expect(find.text('Carnet de Commandes'), findsOneWidget);
    expect(find.byKey(const Key('report-list-panel')), findsOneWidget);
    expect(find.textContaining('DFC · mis à jour'), findsOneWidget);

    // Direction chip filters the list.
    await tester.tap(find.byKey(const Key('group-chip-1')));
    await tester.pumpAndSettle();
    expect(find.text('Trésorerie Pôle Construction'), findsNothing);
    expect(find.text('Carnet de Commandes'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shell-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shell-back')), findsNothing);

    // Favoris tab.
    await tester.tap(find.descendant(of: bar, matching: find.text('Favoris')));
    await tester.pumpAndSettle();
    expect(find.text('Encaissement Clients'), findsOneWidget);
    // Vue mobile meta (phone edition) with the phone icon.
    expect(find.text('Vue mobile'), findsWidgets);
    expect(find.byKey(const Key('report-mobile-icon')), findsWidgets);

    // Tickets tab: title + "Nouveau", no back button.
    await tester.tap(find.descendant(of: bar, matching: find.text('Tickets')));
    await tester.pumpAndSettle();
    expect(find.byType(TicketsScreen), findsOneWidget);
    expect(find.byKey(const Key('tickets-new')), findsOneWidget);
    expect(find.byKey(const Key('screen-back')), findsNothing);

    // Profil tab (former Paramètre), without the Tickets entry.
    await tester.tap(find.descendant(of: bar, matching: find.text('Profil')));
    await tester.pumpAndSettle();
    expect(find.text('Historique'), findsOneWidget);
    expect(find.text('Apparence'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SettingsView),
        matching: find.text('Tickets'),
      ),
      findsNothing,
    );
  });

  testWidgets('consolidé card opens the group with its direction chip', (
    tester,
  ) async {
    setWindowSize(tester, const Size(412, 900));
    await tester.pumpWidget(
      testApp(const ShellScreen(), repo: FakeRepository(), scaffold: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('DFC'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupView), findsOneWidget);
    // Only the DFC reports.
    expect(find.text('Encaissement Clients'), findsOneWidget);
    expect(find.text('Balance Âgée'), findsOneWidget);
    expect(find.text('Suivi Budgétaire'), findsNothing);
    await tester.tap(find.byKey(const Key('group-chip-all')));
    await tester.pumpAndSettle();
    expect(find.text('Suivi Budgétaire'), findsOneWidget);
    // has_mobile_layout → "Vue mobile · DGR".
    expect(find.text('Vue mobile · DGR'), findsOneWidget);
  });

  testWidgets('tablet: glass navigation rail with 4 labels, no tab bar', (
    tester,
  ) async {
    setWindowSize(tester, const Size(1024, 768));
    await tester.pumpWidget(
      testApp(const ShellScreen(), repo: FakeRepository(), scaffold: false),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassTabBar), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
    final labels = ['Accueil', 'Favoris', 'Tickets', 'Profil'];
    final y = <double>[];
    for (final label in labels) {
      final finder = find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text(label),
      );
      expect(finder, findsOneWidget);
      y.add(tester.getCenter(finder).dy);
    }
    expect(y, orderedEquals([...y]..sort()));
    expect(find.byKey(const Key('notification-badge')), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Favoris'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Encaissement Clients'), findsOneWidget);
  });
}
