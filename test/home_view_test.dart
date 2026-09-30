import 'package:cbi_mobile/data/models/catalog.dart';
import 'package:cbi_mobile/data/repositories/demo_fixtures.dart';
import 'package:cbi_mobile/features/home/home_tiles.dart';
import 'package:cbi_mobile/features/home/home_view.dart';
import 'package:cbi_mobile/features/shell/shell_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/contract_fixtures.dart';
import 'support/test_app.dart';

void main() {
  testWidgets('renders catalog sections in order with consolidé cards', (
    tester,
  ) async {
    final repo = FakeRepository(catalog: Catalog.fromJson(demoCatalogJson()));
    await tester.pumpWidget(testApp(const HomeView(), repo: repo));
    await tester.pumpAndSettle();

    final titles = ['Consolidé', 'Pôle', 'Société', 'Modules'];
    for (final t in titles) {
      expect(find.text(t), findsOneWidget);
    }
    final y = [for (final t in titles) tester.getTopLeft(find.text(t)).dy];
    expect(y, orderedEquals([...y]..sort()));

    // Consolidé shows the TABS of its group as cards, labelled by code.
    expect(find.byType(ConsolideCard), findsNWidgets(5));
    for (final code in ['DGR', 'DCG', 'DRH', 'DFC', 'DCO']) {
      expect(
        find.descendant(of: find.byType(ConsolideCard), matching: find.text(code)),
        findsOneWidget,
      );
    }
    // Other sections show groups as tiles with their code as text.
    expect(find.widgetWithText(GroupTile, 'PI'), findsOneWidget);
    expect(find.widgetWithText(GroupTile, 'ALPOSTONE'), findsOneWidget);

    final card = tester.getSize(find.byType(ConsolideCard).first);
    expect(card, const Size(60 + 12, 80 + 12)); // 60x80 + margin 6
  });

  testWidgets('tapping a consolidé card opens the group on that tab', (
    tester,
  ) async {
    final repo = FakeRepository(catalog: Catalog.fromJson(demoCatalogJson()));
    await tester.pumpWidget(testApp(const HomeView(), repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DFC'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeView)),
    );
    final shell = container.read(shellProvider);
    expect(shell.group?.group.key, 'consolide');
    expect(shell.group?.initialTab, 3);
  });

  testWidgets('empty catalog shows the no-access message', (tester) async {
    final repo = FakeRepository(catalog: Catalog.fromJson({'sections': []}));
    await tester.pumpWidget(testApp(const HomeView(), repo: repo));
    await tester.pumpAndSettle();
    expect(find.textContaining("Vous ne disposez d'aucun privilège."), findsOneWidget);
    expect(find.text('Contacter'), findsOneWidget);
  });

  testWidgets('a single group opens its tabs directly', (tester) async {
    final json = contractCatalog()
      ..['sections'] = [contractCatalog()['sections'][1]];
    final repo = FakeRepository(catalog: Catalog.fromJson(json));
    await tester.pumpWidget(testApp(const HomeView(), repo: repo));
    await tester.pumpAndSettle();
    // MDM has one tab → no tab bar, straight to the report list.
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Achats'), findsOneWidget);
  });
}
