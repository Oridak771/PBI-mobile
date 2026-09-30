import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../data/models/catalog.dart';
import '../notifications/notifications_controller.dart';

/// `GET catalog/` state + optimistic favourite toggling.
class CatalogController extends AsyncNotifier<Catalog> {
  @override
  Future<Catalog> build() => _fetch();

  Future<Catalog> _fetch({bool force = false}) async {
    final catalog = await ref
        .read(repositoryProvider)
        .fetchCatalog(force: force);
    if (ref.mounted) {
      ref.read(unreadCountProvider.notifier).set(catalog.unreadNotificationCount);
    }
    return catalog;
  }

  /// Pull-to-refresh. Keeps showing the current data while loading.
  Future<void> refresh() async {
    final result = await AsyncValue.guard(_fetch);
    if (!ref.mounted) return;
    // Keep the previous catalog on a failed refresh.
    if (result.hasError && state.hasValue) return;
    state = result;
  }

  /// Toggles a favourite optimistically; rolls back and returns a French
  /// error message when the server call fails, `null` on success.
  Future<String?> toggleFavorite(int reportId) async {
    final current = state.value;
    if (current == null) return null;
    final wasFavorite = current.isFavorite(reportId);
    state = AsyncData(current.withFavorite(reportId, !wasFavorite));
    try {
      final confirmed = await ref
          .read(repositoryProvider)
          .setFavorite(reportId, !wasFavorite);
      if (ref.mounted && confirmed == wasFavorite) {
        state = AsyncData(state.requireValue.withFavorite(reportId, confirmed));
      }
      return null;
    } catch (e) {
      if (ref.mounted && state.hasValue) {
        state = AsyncData(state.requireValue.withFavorite(reportId, wasFavorite));
      }
      return errorMessage(e);
    }
  }
}

final catalogProvider = AsyncNotifierProvider<CatalogController, Catalog>(
  CatalogController.new,
);
