import 'package:cbi_mobile/data/models/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/contract_fixtures.dart';

void main() {
  late Catalog catalog;
  setUp(() => catalog = Catalog.fromJson(contractCatalog()));

  test('parses servers', () {
    expect(catalog.servers, hasLength(2));
    expect(catalog.servers.first.host, '10.20.10.63');
    expect(catalog.serverHosts, {'10.20.10.63', 'pbirs-mobile.gsh.local'});
    expect(catalog.hostForServer(2), 'pbirs-mobile.gsh.local');
    expect(catalog.hostForServer(99), isNull);
    expect(catalog.generatedAt, isNotNull);
  });

  test('parses group logo_url (optional)', () {
    final mdm = catalog.sections[1].groups.single;
    expect(mdm.logoUrl, '/mobile/v1/metadata/9/logo/?v=societe-3f2a9c1b7d4e');
    expect(catalog.sections.first.groups.single.logoUrl, isNull);
    expect(
      CatalogGroup.fromJson({'key': 'x', 'name': 'X', 'logo_url': ''}).logoUrl,
      isNull,
      reason: 'empty string means no logo',
    );
  });

  test('parses the phone edition of a report (nullable)', () {
    final phone = catalog.reports[12]!.phone;
    expect(phone, isNotNull);
    expect(phone!.id, 31);
    expect(phone.serverId, 2);
    expect(phone.embedUrl, contains('t%C3%A9l%C3%A9phone'));
    expect(catalog.reports[12]!.hasPhoneEdition, isTrue);
    expect(catalog.reports[15]!.phone, isNull, reason: 'explicit null');
    expect(catalog.reports[20]!.phone, isNull, reason: 'absent');
    expect(
      Report.fromJson({
        'id': 1,
        'name': 'r',
        'phone': {'id': 2},
      }).phone,
      isNull,
      reason: 'no embed_url',
    );
    // Kept by copyWith (favourite toggling).
    expect(catalog.withFavorite(12, false).reports[12]!.phone?.id, 31);
  });

  test('open/ response carries the report with its phone edition', () {
    final opening = ReportOpening.fromJson({
      'view_id': 991,
      'embed_url': 'http://10.20.10.63/Reports/powerbi/x?rs:embed=true',
      'server': contractCatalog()['servers'][0],
      'report': contractCatalog()['reports']['12'],
    });
    expect(opening.viewId, 991);
    expect(opening.server?.host, '10.20.10.63');
    expect(opening.report?.phone?.embedUrl, contains('pbirs-mobile.gsh.local'));
    final noPhone = ReportOpening.fromJson({
      'view_id': 1,
      'report': contractCatalog()['reports']['15'],
    });
    expect(noPhone.report?.phone, isNull);
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
