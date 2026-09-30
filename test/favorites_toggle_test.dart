import 'package:cbi_mobile/core/errors/app_exception.dart';
import 'package:cbi_mobile/core/providers.dart';
import 'package:cbi_mobile/core/storage/session_store.dart';
import 'package:cbi_mobile/data/models/catalog.dart';
import 'package:cbi_mobile/features/reports/catalog_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/contract_fixtures.dart';
import 'support/test_app.dart';

void main() {
  late FakeRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeRepository(catalog: Catalog.fromJson(contractCatalog()));
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        sessionStoreProvider.overrideWithValue(MemorySessionStore()),
      ],
    );
    addTearDown(container.dispose);
  });

  test('toggle is optimistic and kept on success', () async {
    await container.read(catalogProvider.future);
    expect(container.read(catalogProvider).requireValue.isFavorite(15), isFalse);

    final pending = container.read(catalogProvider.notifier).toggleFavorite(15);
    // Optimistic: already favourite before the server answers.
    expect(container.read(catalogProvider).requireValue.isFavorite(15), isTrue);
    expect(await pending, isNull);
    expect(container.read(catalogProvider).requireValue.isFavorite(15), isTrue);
    expect(repo.favoriteCalls, 1);
  });

  test('toggle rolls back and returns a French error on failure', () async {
    await container.read(catalogProvider.future);
    repo.favoriteError = const NetworkException();

    final pending = container.read(catalogProvider.notifier).toggleFavorite(12);
    expect(
      container.read(catalogProvider).requireValue.isFavorite(12),
      isFalse,
      reason: 'optimistic removal',
    );
    final error = await pending;
    expect(error, 'Vérifiez votre connexion internet');
    final catalog = container.read(catalogProvider).requireValue;
    expect(catalog.isFavorite(12), isTrue, reason: 'rolled back');
    expect(catalog.favorites.map((r) => r.id), contains(12));
  });
}
