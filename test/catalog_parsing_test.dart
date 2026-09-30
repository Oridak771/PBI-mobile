import 'package:cbi_mobile/data/models/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/contract_fixtures.dart';

void main() {
  late Catalog catalog;
  setUp(() => catalog = Catalog.fromJson(contractCatalog()));

  test('parses servers', () {
    expect(catalog.servers, hasLength(1));
    expect(catalog.servers.single.host, '10.20.10.63');
    expect(catalog.serverHosts, {'10.20.10.63'});
    expect(catalog.generatedAt, isNotNull);
  });

  test('parses sections in order and drops empty sections/groups/tabs', () {
    expect(catalog.sections.map((s) => s.key), ['consolide', 'societe']);
    final consolide = catalog.sections.first;
    expect(consolide.isConsolide, isTrue);
    expect(consolide.layout, SectionLayout.row);
    expect(consolide.groups.single.tabs.single.code, 'DFC');
    expect(consolide.groups.single.tabs.single.reportIds, [12, 15]);

    final societe = catalog.sections[1];
    expect(societe.layout, SectionLayout.grid);
    expect(societe.groups, hasLength(1), reason: 'group without tabs omitted');
    final mdm = societe.groups.single;
    expect(mdm.parent, 'Pôle Production');
    expect(mdm.tabs, hasLength(1), reason: 'tab without reports omitted');
    expect(mdm.tabs.single.label, 'Général', reason: 'no code → name');
    expect(mdm.label, 'MDM');
  });

  test('parses reports keyed by id and resolves tab reports', () {
    expect(catalog.reports.keys, containsAll([12, 15, 20]));
    final tab = catalog.sections.first.groups.single.tabs.single;
    expect(catalog.reportsFor(tab).map((r) => r.name), [
      'Encaissement Clients',
      'Balance Âgée',
    ]);
    expect(catalog.reports[12]!.serverId, 1);
    expect(catalog.reports[12]!.embedUrl, contains('rs:embed=true'));
  });

  test('favorites come from favorite_ids, sorted by location then name', () {
    expect(catalog.favoriteIds, {12, 20});
    expect(catalog.favorites.map((r) => r.id), [12, 20]);
    final toggled = catalog.withFavorite(12, false).withFavorite(15, true);
    // "Consolidé / DFC" sorts before "Société / MDM".
    expect(toggled.favorites.map((r) => r.name), ['Balance Âgée', 'Achats']);
    expect(toggled.isFavorite(12), isFalse);
    expect(toggled.reports[15]!.favorite, isTrue);
  });

  test('unread count and single-group skip rule', () {
    expect(catalog.unreadNotificationCount, 3);
    expect(catalog.singleGroup, isNull);
    final single = Catalog.fromJson({
      ...contractCatalog(),
      'sections': [contractCatalog()['sections'][0]],
    });
    expect(single.singleGroup?.key, 'consolide');
  });

  test('empty catalog means no access', () {
    expect(Catalog.fromJson({'sections': []}).isEmpty, isTrue);
  });
}
