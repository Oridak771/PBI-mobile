import 'package:cbi_mobile/features/shell/shell_header.dart';
import 'package:cbi_mobile/features/shell/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('shell: header, bottom navigation, badge, group back arrow', (
    tester,
  ) async {
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

    // Bottom navigation in legacy order, with the unread badge.
    for (final label in ['Accueil', 'Notification', 'Favoris', 'Paramètre']) {
      expect(
        find.descendant(of: find.byType(BottomNavigationBar), matching: find.text(label)),
        findsOneWidget,
      );
    }
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
}
