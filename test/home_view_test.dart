import 'package:cbi_mobile/data/models/catalog.dart';
import 'package:cbi_mobile/data/models/history.dart';
import 'package:cbi_mobile/data/repositories/demo_fixtures.dart';
import 'package:cbi_mobile/features/history/history_details_screen.dart';
import 'package:cbi_mobile/features/home/home_tiles.dart';
import 'package:cbi_mobile/features/home/home_view.dart';
import 'package:cbi_mobile/features/home/recents_controller.dart';
import 'package:cbi_mobile/features/search/search_screen.dart';
import 'package:cbi_mobile/features/shell/shell_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/contract_fixtures.dart';
import 'support/test_app.dart';

void main() {
  testWidgets('header, search, récents, section chips and the group grid', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeRepository(catalog: Catalog.fromJson(demoCatalogJson()));
    await tester.pumpWidget(testApp(const HomeView(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Bonjour'), findsOneWidget);
    expect(find.byKey(const Key('home-bell')), findsOneWidget);
    expect(find.text('Rechercher un rapport'), findsOneWidget);

    // Récents: distinct reports of GET history/, most recent first.
    expect(find.text('Récents'), findsOneWidget);
    expect(find.text('Tout voir'), findsOneWidget);
    final recents = find.byType(RecentCard);
    expect(recents, findsNWidgets(3));
    expect(
      tester.widget<RecentCard>(recents.first).report.name,
      'Encaissement Clients',
    );
    expect(find.textContaining('Consolidé / DFC · il y a 1 h'), findsOneWidget);

    // Section chips in catalog order, inside the blurred segmented bar.
    final chips = ['Consolidé', 'Pôle', 'Société', 'Modules'];
    final x = <double>[];
    for (final t in chips) {
      final f = find.descendant(
        of: find.byKey(const Key('home-sections')),
        matching: find.text(t),
      );
      expect(f, findsOneWidget);
      x.add(tester.getCenter(f).dx);
    }
    expect(x, orderedEquals([...x]..sort()));

    // Default: the first section (consolidé → its direction tabs as cards).
    expect(find.byType(ConsolideCard), findsNWidgets(5));
    for (final code in ['DGR', 'DCG', 'DRH', 'DFC', 'DCO']) {
      expect(
        find.descendant(of: find.byType(ConsolideCard), matching: find.text(code)),
        findsOneWidget,
      );
    }
    expect(find.text('Direction Finance et Comptabilité'), findsOneWidget);
    // 3-column grid on phones.
    final cards = find.byType(ConsolideCard);
    final ys = {
      for (final e in cards.evaluate()) tester.getTopLeft(find.byWidget(e.widget)).dy,
    };
    expect(ys.length, 2);

    // Société chip: groups as cards with logo/initials, name and count.
    await tester.tap(find.text('Société'));
    await tester.pumpAndSettle();
    expect(find.byType(ConsolideCard), findsNothing);
    expect(find.widgetWithText(GroupCard, 'ALPOSTONE'), findsOneWidget);
    expect(find.widgetWithText(GroupCard, 'Alpostone'), findsOneWidget);
    expect(find.widgetWithText(GroupCard, '3 rapports'), findsWidgets);

    await tester.tap(find.text('Pôle'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(GroupCard, 'PI'), findsOneWidget);
    expect(find.widgetWithText(GroupCard, 'Pôle Industrie'), findsOneWidget);
  });

  testWidgets('"Tout voir" opens the full history', (tester) async {
    final repo = FakeRepository(catalog: Catalog.fromJson(demoCatalogJson()));
    await tester.pumpWidget(testApp(const HomeView(), repo: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recents-all')));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryDetailsScreen), findsOneWidget);
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

  testWidgets('a single group opens its reports directly', (tester) async {
    final json = contractCatalog()
      ..['sections'] = [contractCatalog()['sections'][1]];
    final repo = FakeRepository(catalog: Catalog.fromJson(json));
    await tester.pumpWidget(testApp(const HomeView(), repo: repo));
    await tester.pumpAndSettle();
    // MDM has one tab → no chips, straight to the report list.
    expect(find.byType(TabBar), findsNothing);
    expect(find.byKey(const Key('group-chips')), findsNothing);
    expect(find.text('Achats'), findsOneWidget);
    // The bell stays reachable.
    expect(find.byKey(const Key('home-bell')), findsOneWidget);
  });

  testWidgets('search field opens an instant local search', (tester) async {
    final repo = FakeRepository(catalog: Catalog.fromJson(demoCatalogJson()));
    await tester.pumpWidget(testApp(const HomeView(), repo: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-search')));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(
      find.text("Saisissez le nom ou l'emplacement d'un rapport"),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('search-input')), 'tresorerie');
    await tester.pump();
    expect(find.text('Trésorerie Pôle Construction'), findsOneWidget);
    expect(find.text('Position de Trésorerie'), findsOneWidget);
    expect(find.text('Balance Âgée'), findsNothing);

    // By location too.
    await tester.enterText(find.byKey(const Key('search-input')), 'DRH');
    await tester.pump();
    expect(find.text('Effectifs et Masse Salariale'), findsOneWidget);
    expect(find.text('Absentéisme'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search-input')), 'zzz');
    await tester.pump();
    expect(find.text('Aucun rapport trouvé'), findsOneWidget);
  });

  test('searchReports: accents, case, every word, name or location', () {
    final catalog = Catalog.fromJson(demoCatalogJson());
    List<String> names(String q) =>
        searchReports(catalog, q).map((r) => r.name).toList();
    expect(names(''), isEmpty);
    expect(names('  '), isEmpty);
    expect(names('ÂGÉE'), ['Balance Âgée']);
    expect(names('chiffre societe'), ["Chiffre d'Affaires Société"]);
    expect(names('consolidé dfc'), ['Balance Âgée', 'Encaissement Clients']);
  });

  test('recentReports: distinct, newest first, known reports only, max 6', () {
    final catalog = Catalog.fromJson(demoCatalogJson());
    final now = DateTime(2026, 10, 5, 12);
    HistoryItem item(int id, int reportId, int hoursAgo) => HistoryItem(
      id: id,
      reportId: reportId,
      reportName: 'r$reportId',
      openedAt: now.subtract(Duration(hours: hoursAgo)),
    );
    final recents = recentReports([
      item(1, 5, 3),
      item(2, 1, 1),
      item(3, 5, 0),
      item(4, 999, 0), // not in the catalog
      for (var i = 0; i < 8; i++) item(10 + i, 6 + i, 10 + i),
    ], catalog);
    expect(recents.first.report.id, 5);
    expect(recents.map((r) => r.report.id).toSet().length, recents.length);
    expect(recents.length, 6);
    expect(recents.any((r) => r.report.id == 999), isFalse);
  });
}
