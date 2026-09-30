import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/models/remote_config.dart';
import '../data/repositories/api_cbi_repository.dart';
import '../data/repositories/cbi_repository.dart';
import '../data/repositories/demo_cbi_repository.dart';
import 'api/api_client.dart';
import 'config/app_config.dart';
import 'storage/session_store.dart';

/// Compile-time configuration (`--dart-define`).
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

final sessionStoreProvider = Provider<SessionStore>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.demoMode ? MemorySessionStore() : SecureSessionStore();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(config: ref.watch(appConfigProvider));
  ref.onDispose(client.close);
  return client;
});

/// The data source: the real API, or fixtures in demo mode.
final repositoryProvider = Provider<CbiRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.demoMode) return DemoCbiRepository();
  return ApiCbiRepository(ref.watch(apiClientProvider));
});

/// Installed app version (`version` of pubspec, e.g. `3.0.0`).
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// `GET config/`; falls back to defaults when the server is unreachable.
final remoteConfigProvider = FutureProvider<RemoteConfig>((ref) async {
  try {
    return await ref.watch(repositoryProvider).fetchConfig();
  } catch (_) {
    return const RemoteConfig();
  }
});

/// Profile photo bytes for a `photo_url` (with the Bearer header).
final photoProvider = FutureProvider.family<Uint8List?, String>((ref, url) async {
  try {
    return await ref.watch(repositoryProvider).fetchPhoto(url);
  } catch (_) {
    return null;
  }
});
