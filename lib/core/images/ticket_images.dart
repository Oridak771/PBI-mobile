import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/demo_fixtures.dart';
import '../providers.dart';
import 'logo_images.dart';

/// Disk cache of the ticket / message attachments.
///
/// Unlike the logos these URLs are not versioned: the normal HTTP caching
/// applies (the server sends `Cache-Control: private, max-age=86400`) and
/// unused files are dropped after a week.
class TicketImageCacheManager extends CacheManager with ImageCacheManager {
  TicketImageCacheManager._()
    : super(
        Config(
          key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 200,
        ),
      );

  static const key = 'cbiTicketImages';
  static final instance = TicketImageCacheManager._();
}

/// Overridable in tests (the real cache touches the file system).
final ticketImageCacheManagerProvider = Provider<BaseCacheManager>(
  (ref) => TicketImageCacheManager.instance,
);

/// Image of an `attachment_url` (ticket or message), `null` when it cannot
/// be displayed. Real mode: fetched with the Bearer header (only towards the
/// CBI platform itself). Demo mode: a bundled image.
final ticketImageResolverProvider = Provider<LogoImageResolver>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.demoMode) {
    return (url) {
      final asset = demoAttachmentAsset(url);
      return asset == null ? null : AssetImage(asset);
    };
  }
  final client = ref.watch(apiClientProvider);
  final cache = ref.watch(ticketImageCacheManagerProvider);
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
