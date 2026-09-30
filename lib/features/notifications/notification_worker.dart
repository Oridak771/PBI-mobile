import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/session_store.dart';
import '../../data/models/notification.dart';
import '../../data/repositories/api_cbi_repository.dart';
import '../../data/repositories/cbi_repository.dart';
import 'local_notifications.dart';

const notificationTaskUniqueName = 'cbi-notifications-poll';
const notificationTaskName = 'pollNotifications';

/// WorkManager entry point (runs in a background isolate every ~15 min).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    try {
      final config = AppConfig.fromEnvironment();
      if (config.demoMode || !config.hasValidBaseUrl) return true;
      final store = SecureSessionStore();
      final session = await store.read();
      if (session == null) return true;
      final client = ApiClient(config: config)..token = session.token;
      try {
        final fresh = await pollNewNotifications(
          ApiCbiRepository(client),
          store,
        );
        if (fresh.isNotEmpty) await LocalNotifications.initialise();
        for (final n in fresh) {
          await LocalNotifications.show(n);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Notification poll failed: $e');
    }
    // Always succeed: the periodic schedule handles the next attempt.
    return true;
  });
}

/// Fetches `notifications/?after=<last_seen_id>`, stores the new `latest_id`
/// and returns the notifications to raise (oldest first, unread only, max 5).
///
/// The very first poll after login only records the current `latest_id` so
/// old notifications are not replayed.
Future<List<AppNotification>> pollNewNotifications(
  CbiRepository repository,
  SessionStore store,
) async {
  final lastSeen = await store.lastSeenNotificationId();
  final page = await repository.fetchNotifications(
    after: lastSeen > 0 ? lastSeen : null,
  );
  final latest = page.latestId > lastSeen ? page.latestId : lastSeen;
  await store.setLastSeenNotificationId(latest);
  if (lastSeen == 0) return const [];
  final fresh =
      page.notifications.where((n) => n.id > lastSeen && !n.isRead).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  return fresh.length > 5 ? fresh.sublist(fresh.length - 5) : fresh;
}
