import 'package:cbi_mobile/core/storage/session_store.dart';
import 'package:cbi_mobile/data/models/notification.dart';
import 'package:cbi_mobile/features/notifications/notification_worker.dart';
import 'package:cbi_mobile/features/notifications/notifications_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

Map<String, dynamic> _n(int id, String title, {required bool isNew, bool read = false}) => {
  'id': id,
  'title': title,
  'kind': 'info',
  'message': 'Message $id',
  'created_at': DateTime.now().subtract(Duration(hours: id)).toIso8601String(),
  'is_read': read,
  'is_new': isNew,
};

NotificationsPage _page(List<Map<String, dynamic>> items, {int unread = 0}) =>
    NotificationsPage.fromJson({
      'notifications': items,
      'unread_count': unread,
      'latest_id': items.isEmpty ? 0 : items.first['id'],
    });

void main() {
  test('splits Nouveau (is_new) and Déjà vu', () {
    final page = _page([
      _n(9, 'A', isNew: true),
      _n(8, 'B', isNew: true, read: true),
      _n(3, 'C', isNew: false),
    ], unread: 2);
    expect(page.recent.map((n) => n.id), [9, 8]);
    expect(page.older.map((n) => n.id), [3]);
    expect(page.unreadCount, 2);
    expect(page.latestId, 9);
  });

  testWidgets('renders both sections with their items', (tester) async {
    final repo = FakeRepository(
      notifications: _page([
        _n(9, 'Accès', isNew: true),
        _n(3, 'Ancienne', isNew: false, read: true),
      ], unread: 1),
    );
    await tester.pumpWidget(testApp(const NotificationsView(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Nouveau'), findsOneWidget);
    expect(find.text('Déjà vu'), findsOneWidget);
    expect(find.text('Tout marquer comme lu'), findsOneWidget);
    final nouveauY = tester.getTopLeft(find.text('Nouveau')).dy;
    final dejaVuY = tester.getTopLeft(find.text('Déjà vu')).dy;
    final recentY = tester.getTopLeft(find.text('Accès')).dy;
    final olderY = tester.getTopLeft(find.text('Ancienne')).dy;
    expect(nouveauY < recentY && recentY < dejaVuY && dejaVuY < olderY, isTrue);

    // Unread title in blue, read one in grey.
    expect(tester.widget<Text>(find.text('Accès')).style?.color, const Color(0xFF0099D5));
    expect(tester.widget<Text>(find.text('Ancienne')).style?.color, const Color(0xFFABABAB));
  });

  testWidgets('empty sections show the legacy messages', (tester) async {
    final repo = FakeRepository(notifications: _page([]));
    await tester.pumpWidget(testApp(const NotificationsView(), repo: repo));
    await tester.pumpAndSettle();
    expect(find.text('Aucune nouvelle notification'), findsOneWidget);
    expect(find.text('Aucune notification'), findsOneWidget);
    expect(find.text('Tout marquer comme lu'), findsNothing);
  });

  group('background poll', () {
    test('first poll only records latest_id', () async {
      final store = MemorySessionStore();
      final repo = FakeRepository(notifications: _page([_n(8, 'x', isNew: true)]));
      expect(await pollNewNotifications(repo, store), isEmpty);
      expect(await store.lastSeenNotificationId(), 8);
    });

    test('returns unread notifications newer than last seen, oldest first', () async {
      final store = MemorySessionStore();
      await store.setLastSeenNotificationId(5);
      final repo = FakeRepository(
        notifications: _page([
          _n(8, 'c', isNew: true),
          _n(7, 'b', isNew: true, read: true),
          _n(6, 'a', isNew: true),
        ]),
      );
      final fresh = await pollNewNotifications(repo, store);
      expect(fresh.map((n) => n.id), [6, 8]);
      expect(await store.lastSeenNotificationId(), 8);
    });
  });
}
