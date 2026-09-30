import 'dart:async';
import 'dart:typed_data';

import '../models/catalog.dart';
import '../models/history.dart';
import '../models/notification.dart';
import '../models/remote_config.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import 'cbi_repository.dart';
import 'demo_fixtures.dart';

/// Offline repository returning contract-shaped fixtures
/// (`--dart-define=ENABLE_DEMO_MODE=true`).
class DemoCbiRepository implements CbiRepository {
  DemoCbiRepository({this.latency = const Duration(milliseconds: 300)});

  final Duration latency;

  late Catalog _catalog = Catalog.fromJson(demoCatalogJson());
  late NotificationsPage _notifications = NotificationsPage.fromJson(
    demoNotificationsJson(),
  );
  late final List<Ticket> _tickets = demoTicketsJson()
      .map(Ticket.fromJson)
      .toList();
  int _nextViewId = 1000;

  Future<void> _wait() => Future<void>.delayed(latency);

  @override
  set token(String? value) {}

  @override
  Future<RemoteConfig> fetchConfig() async {
    await _wait();
    return RemoteConfig.fromJson(demoConfigJson());
  }

  @override
  Future<LoginResult> login({
    required String username,
    required String password,
    String? device,
    String? appVersion,
  }) async {
    await _wait();
    return LoginResult.fromJson(demoLoginJson());
  }

  @override
  Future<void> logout() => _wait();

  @override
  Future<User> fetchMe() async {
    await _wait();
    return User.fromJson(demoUserJson());
  }

  @override
  Future<Uint8List?> fetchPhoto(String photoUrl) async => null;

  @override
  Future<Catalog> fetchCatalog({bool force = false}) async {
    await _wait();
    return _catalog.copyWith(unreadNotificationCount: _notifications.unreadCount);
  }

  @override
  Future<ReportOpening> openReport(int reportId) async {
    await _wait();
    final report = _catalog.reports[reportId];
    return ReportOpening(
      viewId: _nextViewId++,
      embedUrl: report?.embedUrl ?? '',
      server: _catalog.servers.isEmpty ? null : _catalog.servers.first,
      report: report,
    );
  }

  @override
  Future<void> closeReport(
    int reportId, {
    required int viewId,
    required int durationSeconds,
  }) async {}

  @override
  Future<bool> setFavorite(int reportId, bool favorite) async {
    await _wait();
    _catalog = _catalog.withFavorite(reportId, favorite);
    return favorite;
  }

  @override
  Future<NotificationsPage> fetchNotifications({
    int? after,
    int limit = 50,
  }) async {
    await _wait();
    if (after == null) return _notifications;
    return NotificationsPage(
      notifications: _notifications.notifications
          .where((n) => n.id > after)
          .toList(),
      unreadCount: _notifications.unreadCount,
      latestId: _notifications.latestId,
    );
  }

  @override
  Future<UnreadCount> fetchUnreadCount() async => UnreadCount(
    unreadCount: _notifications.unreadCount,
    latestId: _notifications.latestId,
  );

  @override
  Future<int> markNotificationRead(int id) async {
    await _wait();
    final list = [
      for (final n in _notifications.notifications)
        n.id == id ? n.copyWith(isRead: true) : n,
    ];
    _notifications = _notifications.copyWith(
      notifications: list,
      unreadCount: list.where((n) => !n.isRead).length,
    );
    return _notifications.unreadCount;
  }

  @override
  Future<int> markAllNotificationsRead() async {
    await _wait();
    _notifications = _notifications.copyWith(
      notifications: [
        for (final n in _notifications.notifications) n.copyWith(isRead: true),
      ],
      unreadCount: 0,
    );
    return 0;
  }

  @override
  Future<List<HistoryItem>> fetchMyHistory({int days = 30}) async {
    await _wait();
    return demoHistoryJson().map(HistoryItem.fromJson).toList();
  }

  @override
  Future<HistoryUsersPage> fetchHistoryUsers({
    String q = '',
    String company = '',
    int limit = 50,
    int offset = 0,
  }) async {
    await _wait();
    final page = HistoryUsersPage.fromJson(demoHistoryUsersJson());
    final results = page.results.where((e) {
      final okQ = q.isEmpty || e.user.name.toLowerCase().contains(q.toLowerCase());
      final okC =
          company.isEmpty ||
          e.user.company.toLowerCase().contains(company.toLowerCase());
      return okQ && okC;
    }).toList();
    return HistoryUsersPage(
      count: results.length,
      results: offset >= results.length ? const [] : results.skip(offset).take(limit).toList(),
    );
  }

  @override
  Future<UserHistory> fetchUserHistory(int userId, {int days = 30}) async {
    await _wait();
    final entry = HistoryUsersPage.fromJson(demoHistoryUsersJson()).results
        .firstWhere(
          (e) => e.user.id == userId,
          orElse: () => HistoryUsersPage.fromJson(demoHistoryUsersJson()).results.first,
        );
    return UserHistory(
      user: entry.user,
      history: demoHistoryJson().map(HistoryItem.fromJson).toList(),
    );
  }

  @override
  Future<List<Ticket>> fetchTickets() async {
    await _wait();
    return List.of(_tickets);
  }

  @override
  Future<Ticket> createTicket(NewTicket ticket) async {
    await _wait();
    final created = Ticket(
      id: _tickets.length + 10,
      title: ticket.title,
      description: ticket.description,
      ticketType: ticket.ticketType,
      ticketTypeLabel: ticketTypes[ticket.ticketType] ?? ticket.ticketType,
      priority: ticket.priority,
      status: 'open',
      statusLabel: 'Ouvert',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _tickets.insert(0, created);
    return created;
  }

  @override
  Future<Ticket> fetchTicket(int id) async {
    await _wait();
    return _tickets.firstWhere((t) => t.id == id);
  }

  @override
  Future<TicketMessage> sendTicketMessage(int ticketId, String content) async {
    await _wait();
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    final message = TicketMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      sender: 'Utilisateur Démo',
      isMine: true,
      content: content,
      createdAt: DateTime.now(),
    );
    if (index >= 0) {
      final t = _tickets[index];
      _tickets[index] = Ticket(
        id: t.id,
        title: t.title,
        description: t.description,
        ticketType: t.ticketType,
        ticketTypeLabel: t.ticketTypeLabel,
        priority: t.priority,
        status: t.status,
        statusLabel: t.statusLabel,
        createdAt: t.createdAt,
        updatedAt: DateTime.now(),
        messagesCount: t.messagesCount + 1,
        messages: [...t.messages, message],
      );
    }
    return message;
  }
}
