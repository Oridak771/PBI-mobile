import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../data/models/notification.dart';

/// Badge of the "Notification" bottom tab.
class UnreadCountController extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value < 0 ? 0 : value;

  /// `GET notifications/unread-count/` (foreground poller, app resume).
  Future<void> refresh() async {
    try {
      final result = await ref.read(repositoryProvider).fetchUnreadCount();
      if (!ref.mounted) return;
      set(result.unreadCount);
      await _markSeen(result.latestId);
    } catch (_) {
      // Polling is best-effort; errors (401 included) are handled globally.
    }
  }

  /// Notifications seen while the app is in the foreground must not be
  /// raised again by the background worker.
  Future<void> _markSeen(int latestId) async {
    final store = ref.read(sessionStoreProvider);
    if (latestId > await store.lastSeenNotificationId()) {
      await store.setLastSeenNotificationId(latestId);
    }
  }
}

final unreadCountProvider = NotifierProvider<UnreadCountController, int>(
  UnreadCountController.new,
);

/// `GET notifications/` list + read actions.
class NotificationsController extends AsyncNotifier<NotificationsPage> {
  @override
  Future<NotificationsPage> build() => _fetch();

  Future<NotificationsPage> _fetch() async {
    final page = await ref.read(repositoryProvider).fetchNotifications();
    if (ref.mounted) {
      ref.read(unreadCountProvider.notifier).set(page.unreadCount);
      final store = ref.read(sessionStoreProvider);
      if (page.latestId > await store.lastSeenNotificationId()) {
        await store.setLastSeenNotificationId(page.latestId);
      }
    }
    return page;
  }

  Future<void> refresh() async {
    final result = await AsyncValue.guard(_fetch);
    if (!ref.mounted) return;
    if (result.hasError && state.hasValue) return;
    state = result;
  }

  /// `POST notifications/<id>/read/`, optimistic. Returns an error message.
  Future<String?> markRead(int id) async {
    final page = state.value;
    if (page == null) return null;
    final target = page.notifications.where((n) => n.id == id).firstOrNull;
    if (target == null || target.isRead) return null;
    _apply(page, (n) => n.id == id);
    try {
      final unread = await ref.read(repositoryProvider).markNotificationRead(id);
      if (ref.mounted) ref.read(unreadCountProvider.notifier).set(unread);
      return null;
    } catch (e) {
      if (ref.mounted) {
        state = AsyncData(page);
        ref.read(unreadCountProvider.notifier).set(page.unreadCount);
      }
      return errorMessage(e);
    }
  }

  /// `POST notifications/read-all/`.
  Future<String?> markAllRead() async {
    final page = state.value;
    if (page == null) return null;
    _apply(page, (_) => true);
    try {
      final unread = await ref.read(repositoryProvider).markAllNotificationsRead();
      if (ref.mounted) ref.read(unreadCountProvider.notifier).set(unread);
      return null;
    } catch (e) {
      if (ref.mounted) {
        state = AsyncData(page);
        ref.read(unreadCountProvider.notifier).set(page.unreadCount);
      }
      return errorMessage(e);
    }
  }

  void _apply(NotificationsPage page, bool Function(AppNotification) test) {
    bool marks(AppNotification n) => !n.isRead && test(n);
    final marked = page.notifications.where(marks).length;
    final list = [
      for (final n in page.notifications) marks(n) ? n.copyWith(isRead: true) : n,
    ];
    // Optimistic count; the server's `unread_count` replaces it right after.
    final unread = page.unreadCount - marked < 0 ? 0 : page.unreadCount - marked;
    state = AsyncData(page.copyWith(notifications: list, unreadCount: unread));
    ref.read(unreadCountProvider.notifier).set(unread);
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsController, NotificationsPage>(
      NotificationsController.new,
    );
