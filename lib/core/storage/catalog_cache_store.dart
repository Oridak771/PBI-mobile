import 'package:shared_preferences/shared_preferences.dart';

/// Last `GET catalog/` answer (raw JSON + ETag), so the home screen shows the
/// catalog immediately at launch while a fresh copy loads in the background.
/// Wiped when the session ends (logout / 401).
class CachedCatalogEntry {
  const CachedCatalogEntry({required this.json, this.etag});

  final String json;
  final String? etag;
}

abstract class CatalogCacheStore {
  Future<CachedCatalogEntry?> read();
  Future<void> write(CachedCatalogEntry entry);
  Future<void> clear();
}

/// App-private `shared_preferences` (the app disables Android backups).
class PrefsCatalogCacheStore implements CatalogCacheStore {
  const PrefsCatalogCacheStore();

  static const jsonKey = 'catalog_cache_json';
  static const etagKey = 'catalog_cache_etag';

  @override
  Future<CachedCatalogEntry?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(jsonKey);
      if (json == null || json.isEmpty) return null;
      return CachedCatalogEntry(json: json, etag: prefs.getString(etagKey));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(CachedCatalogEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(jsonKey, entry.json);
      final etag = entry.etag;
      if (etag == null) {
        await prefs.remove(etagKey);
      } else {
        await prefs.setString(etagKey, etag);
      }
    } catch (_) {
      // A cache: losing it only costs one full download.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(jsonKey);
      await prefs.remove(etagKey);
    } catch (_) {}
  }
}

class MemoryCatalogCacheStore implements CatalogCacheStore {
  MemoryCatalogCacheStore([this.entry]);

  CachedCatalogEntry? entry;

  @override
  Future<CachedCatalogEntry?> read() async => entry;

  @override
  Future<void> write(CachedCatalogEntry entry) async => this.entry = entry;

  @override
  Future<void> clear() async => entry = null;
}
