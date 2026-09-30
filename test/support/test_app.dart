import 'package:cbi_mobile/core/providers.dart';
import 'package:cbi_mobile/core/storage/session_store.dart';
import 'package:cbi_mobile/core/theme/app_theme.dart';
import 'package:cbi_mobile/data/models/catalog.dart';
import 'package:cbi_mobile/data/models/notification.dart';
import 'package:cbi_mobile/data/models/user.dart';
import 'package:cbi_mobile/data/repositories/demo_cbi_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Demo repository without latency whose behaviour tests can tweak.
class FakeRepository extends DemoCbiRepository {
  FakeRepository({this.catalog, this.notifications})
    : super(latency: Duration.zero);

  Catalog? catalog;
  NotificationsPage? notifications;
  Object? loginError;
  Object? favoriteError;
  int favoriteCalls = 0;

  @override
  Future<Catalog> fetchCatalog({bool force = false}) async =>
      catalog ?? super.fetchCatalog(force: force);

  @override
  Future<NotificationsPage> fetchNotifications({int? after, int limit = 50}) async =>
      notifications ?? super.fetchNotifications(after: after, limit: limit);

  @override
  Future<LoginResult> login({
    required String username,
    required String password,
    String? device,
    String? appVersion,
  }) async {
    if (loginError != null) throw loginError!;
    return super.login(username: username, password: password);
  }

  @override
  Future<bool> setFavorite(int reportId, bool favorite) async {
    favoriteCalls++;
    if (favoriteError != null) throw favoriteError!;
    return super.setFavorite(reportId, favorite);
  }
}

/// Wraps [child] in a ProviderScope + themed MaterialApp + Scaffold.
Widget testApp(
  Widget child, {
  required FakeRepository repo,
  SessionStore? store,
  bool scaffold = true,
}) => ProviderScope(
  retry: (_, _) => null,
  overrides: [
    repositoryProvider.overrideWithValue(repo),
    sessionStoreProvider.overrideWithValue(store ?? MemorySessionStore()),
    appVersionProvider.overrideWith((ref) => '3.0.0'),
  ],
  child: MaterialApp(
    theme: buildAppTheme(),
    home: scaffold ? Scaffold(body: child) : child,
  ),
);
