import 'package:cbi_mobile/core/assets.dart';
import 'package:cbi_mobile/features/shell/shell_header.dart';
import 'package:cbi_mobile/features/shell/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('shell: header, bottom navigation, badge, group back arrow', (
    tester,
  ) async {
    // Phone width: bottom navigation bar (compact window).
    setWindowSize(tester, const Size(412, 900));
    await tester.pumpWidget(
      testApp(const ShellScreen(), repo: FakeRepository(), scaffold: false),
    );
    await tester.pumpAndSettle();

    // Header title + no back arrow on root tabs.
    expect(
      find.descendant(of: find.byType(ShellHeader), matching: find.text('Accueil')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('shell-back')), findsNothing);

    // Theme-aware PBI mark on the right of the header (light theme here).
    expect(
      find.descendant(
        of: find.byType(ShellHeader),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName == AppAssets.pbiMarkOnLight,
        ),
      ),
      findsOneWidget,
    );

    // Material 3 navigation bar in legacy order, with the unread badge.
    final labels = ['Accueil', 'Notification', 'Favoris', 'Paramètre'];
    final x = <double>[];
    for (final label in labels) {
      final finder = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      expect(finder, findsOneWidget);
      x.add(tester.getCenter(finder).dx);
    }
    expect(x, orderedEquals([...x]..sort()));
    expect(
      find.descendant(of: find.byKey(const Key('notification-badge')), matching: find.text('2')),
      findsOneWidget,
    );

    // Open a pole group: title = group name, back arrow shown, tabs by code.
    await tester.tap(find.text('PC'));
    await tester.pumpAndSettle();
    expect(find.text('Pôle Construction'), findsOneWidget);
    expect(find.byKey(const Key('shell-back')), findsOneWidget);
    expect(find.widgetWithText(Tab, 'DFC'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'DCO'), findsOneWidget);
    expect(find.text('Trésorerie Pôle Construction'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shell-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shell-back')), findsNothing);

    // Favoris tab.
    await tester.tap(find.text('Favoris'));
    await tester.pumpAndSettle();
    expect(find.text('Encaissement Clients'), findsOneWidget);
  });

  testWidgets('tablet: navigation rail with labels and badge, no bottom bar', (
    tester,
  ) async {
    setWindowSize(tester, const Size(1024, 768));
    await tester.pumpWidget(
      testApp(const ShellScreen(), repo: FakeRepository(), scaffold: false),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
    final labels = ['Accueil', 'Notification', 'Favoris', 'Paramètre'];
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
    expect(
      find.descendant(
        of: find.byKey(const Key('notification-badge')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

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
