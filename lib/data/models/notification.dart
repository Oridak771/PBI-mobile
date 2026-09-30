import '../../core/utils/json.dart';

/// One entry of `GET notifications/`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.kind = 'info',
    this.message = '',
    this.createdAt,
    this.isRead = false,
    this.isNew = false,
  });

  factory AppNotification.fromJson(Json json) => AppNotification(
    id: asInt(json['id']),
    title: asString(json['title']),
    kind: asString(json['kind'], 'info'),
    message: asString(json['message']),
    createdAt: asDate(json['created_at']),
    isRead: asBool(json['is_read']),
    isNew: asBool(json['is_new']),
  );

  final int id;
  final String title;

  /// `access` | `report` | `info`.
  final String kind;
  final String message;
  final DateTime? createdAt;
  final bool isRead;

  /// Created during the last 7 days → "Nouveau" section.
  final bool isNew;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    kind: kind,
    message: message,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    isNew: isNew,
  );
}

class NotificationsPage {
  const NotificationsPage({
    this.notifications = const [],
    this.unreadCount = 0,
    this.latestId = 0,
  });

  factory NotificationsPage.fromJson(Json json) => NotificationsPage(
    notifications: asMapList(
      json['notifications'],
    ).map(AppNotification.fromJson).toList(),
    unreadCount: asInt(json['unread_count']),
    latestId: asInt(json['latest_id']),
  );

  final List<AppNotification> notifications;
  final int unreadCount;
  final int latestId;

  /// "Nouveau" items (`is_new == true`).
  List<AppNotification> get recent =>
      notifications.where((n) => n.isNew).toList();

  /// "Déjà vu" items (older ones).
  List<AppNotification> get older =>
      notifications.where((n) => !n.isNew).toList();

  NotificationsPage copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
  }) => NotificationsPage(
    notifications: notifications ?? this.notifications,
    unreadCount: unreadCount ?? this.unreadCount,
    latestId: latestId,
  );
}

/// `GET notifications/unread-count/`.
class UnreadCount {
  const UnreadCount({this.unreadCount = 0, this.latestId = 0});

  factory UnreadCount.fromJson(Json json) => UnreadCount(
    unreadCount: asInt(json['unread_count']),
    latestId: asInt(json['latest_id']),
  );

  final int unreadCount;
  final int latestId;
}
