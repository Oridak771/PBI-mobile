import 'dart:async';

import 'package:cbi_mobile/core/providers.dart';
import 'package:cbi_mobile/data/models/catalog.dart';
import 'package:cbi_mobile/data/repositories/demo_fixtures.dart';
import 'package:cbi_mobile/features/reports/catalog_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/contract_fixtures.dart';
import 'support/test_app.dart';

/// Has a saved catalog; the network answer waits for [gate].
class _CachedRepository extends FakeRepository {
  _CachedRepository(this.saved, Catalog fresh) : super(catalog: fresh);

  final Catalog saved;
  final gate = Completer<void>();
  int fetches = 0;

  @override
  Future<Catalog?> cachedCatalog() async => saved;

  @override
  Future<Catalog> fetchCatalog({bool force = false}) async {
    fetches++;
    await gate.future;
    return super.fetchCatalog(force: force);
  }
}

void main() {
  test('launch shows the saved catalog, then the background refresh', () async {
    final saved = Catalog.fromJson(contractCatalog());
    final fresh = Catalog.fromJson(demoCatalogJson());
    final repo = _CachedRepository(saved, fresh);
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final first = await container.read(catalogProvider.future);
    expect(identical(first, saved), isTrue, reason: 'no wait for the network');
    await Future<void>.delayed(Duration.zero);
    expect(repo.fetches, 1, reason: 'refreshed in the background');

    repo.gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
      container.read(catalogProvider).value?.sections.length,
      fresh.sections.length,
    );
  });
}
