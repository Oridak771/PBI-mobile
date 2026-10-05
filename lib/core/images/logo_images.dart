import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/demo_fixtures.dart';
import '../providers.dart';

/// Builds the image of a pôle / société `logo_url`, or `null` when it cannot
/// be displayed (the card then shows the initials tile).
typedef LogoImageResolver = ImageProvider? Function(String logoUrl);

/// Disk cache of the group logos.
///
/// `logo_url` is versioned (`?v=…` changes with the logo), so a cached file
/// never needs revalidation: entries are kept "forever" (10 years, 500 logos)
/// whatever the response's `Cache-Control` says.
class LogoCacheManager extends CacheManager with ImageCacheManager {
  LogoCacheManager._()
    : super(
        Config(
          key,
          stalePeriod: const Duration(days: 3650),
          maxNrOfCacheObjects: 500,
          fileService: ImmutableFileService(HttpFileService()),
        ),
      );

  static const key = 'cbiGroupLogos';
  static final instance = LogoCacheManager._();
}

/// Marks every downloaded file as valid for [validFor] (immutable URLs).
class ImmutableFileService extends FileService {
  ImmutableFileService(
    this._inner, {
    this.validFor = const Duration(days: 3650),
  });

  final FileService _inner;
  final Duration validFor;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async => _ImmutableResponse(
    await _inner.get(url, headers: headers),
    DateTime.now().add(validFor),
  );
}

class _ImmutableResponse implements FileServiceResponse {
  _ImmutableResponse(this._inner, this.validTill);

  final FileServiceResponse _inner;

  @override
  final DateTime validTill;

  @override
  Stream<List<int>> get content => _inner.content;

  @override
  int? get contentLength => _inner.contentLength;

  @override
  String? get eTag => _inner.eTag;

  @override
  String get fileExtension => _inner.fileExtension;

  @override
  int get statusCode => _inner.statusCode;
}

/// Cache used for the logos (overridable in tests: the real one touches the
/// file system as soon as it is created).
final logoCacheManagerProvider = Provider<BaseCacheManager>(
  (ref) => LogoCacheManager.instance,
);

/// Real mode: `logo_url` resolved against `API_BASE_URL`, fetched with the
/// Bearer header (only towards the CBI platform itself) and cached on disk.
/// Demo mode: the fixture logos map to bundled images.
final logoImageResolverProvider = Provider<LogoImageResolver>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.demoMode) {
    return (url) {
      final asset = demoLogoAsset(url);
      return asset == null ? null : AssetImage(asset);
    };
  }
  final client = ref.watch(apiClientProvider);
  final cache = ref.watch(logoCacheManagerProvider);
  return (url) {
    if (url.trim().isEmpty || !config.hasValidBaseUrl) return null;
    final uri = config.resolve(url.trim());
    if (!uri.hasScheme) return null;
    final token = client.token;
    return CachedNetworkImageProvider(
      uri.toString(),
      cacheManager: cache,
      headers: {
        if (token != null && config.isApiOrigin(uri))
          'Authorization': 'Bearer $token',
      },
    );
  };
});
