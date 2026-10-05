import 'dart:async';
import 'dart:typed_data';

import '../../core/errors/app_exception.dart';
import '../../core/utils/json.dart';

import '../models/catalog.dart';
import '../models/history.dart';
import '../models/mobile_layout.dart';
import '../models/notification.dart';
import '../models/remote_config.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import 'cbi_repository.dart';
import 'demo_fixtures.dart';

/// Offline repository returning contract-shaped fixtures
/// (`--dart-define=ENABLE_DEMO_MODE=true`).
class DemoCbiRepository implements CbiRepository {
  DemoCbiRepository({
    this.latency = const Duration(milliseconds: 300),
    this.ticketAdmin = true,
  });

  final Duration latency;

  /// The demo user manages tickets (sees all, changes status / assignee).
  final bool ticketAdmin;

  static const demoUserId = 42;

  late Catalog _catalog = Catalog.fromJson(demoCatalogJson());
  late NotificationsPage _notifications = NotificationsPage.fromJson(
    demoNotificationsJson(),
  );
  late final List<Ticket> _tickets = demoTicketsJson()
      .map(Ticket.fromJson)
      .toList();
  int _nextTicketId = 100;
  int _nextMessageId = 100;
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
  Future<Catalog?> cachedCatalog() async => null;

  @override
  Future<void> clearCatalogCache() async {}

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
  Future<MobileLayout> fetchMobileLayout(int reportId) async {
    await _wait();
    return MobileLayout.fromJson(demoMobileLayoutJson(reportId));
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

  TicketChoices get _choices =>
      TicketChoices.fromJson(demoTicketChoicesJson(isAdmin: ticketAdmin));

  TicketPerson get _me => TicketPerson.fromJsonOrNull(demoPersonJson(demoUserId))!;

  bool _visible(Ticket t) => ticketAdmin || t.createdBy?.id == demoUserId;

  @override
  Future<TicketChoices> fetchTicketChoices() async {
    await _wait();
    return _choices;
  }

  @override
  Future<TicketList> fetchTickets({
    TicketFilter filter = TicketFilter.all,
  }) async {
    await _wait();
    return TicketList(
      isAdmin: ticketAdmin,
      tickets: [
        for (final t in _tickets)
          if (_visible(t) &&
              filter.matches(t, myId: demoUserId, isAdmin: ticketAdmin))
            t.copyWith(messages: const [], canManage: false),
      ],
    );
  }

  String? _demoAttachmentUrl(TicketAttachment? attachment, String key) =>
      attachment == null ? null : '$demoAttachmentPrefix$key/';

  @override
  Future<Ticket> createTicket(NewTicket ticket) async {
    await _wait();
    final c = _choices;
    final now = DateTime.now();
    final id = _nextTicketId++;
    final created = Ticket(
      id: id,
      title: ticket.title,
      description: ticket.description,
      ticketType: ticket.ticketType,
      ticketTypeLabel: TicketChoices.labelOf(c.ticketTypes, ticket.ticketType),
      category: ticket.category,
      categoryLabel: TicketChoices.labelOf(c.categories, ticket.category),
      priority: ticket.priority,
      priorityLabel: TicketChoices.labelOf(c.priorities, ticket.priority),
      status: 'open',
      statusLabel: TicketChoices.labelOf(c.statuses, 'open'),
      createdBy: _me,
      attachmentUrl: _demoAttachmentUrl(ticket.attachment, 't$id'),
      createdAt: now,
      updatedAt: now,
    );
    _tickets.insert(0, created);
    return created;
  }

  @override
  Future<Ticket> fetchTicket(int id) async {
    await _wait();
    final ticket = _tickets.firstWhere(
      (t) => t.id == id && _visible(t),
      orElse: () => throw const ApiException(
        statusCode: 404,
        code: 'not_found',
        detail: 'Ticket introuvable.',
      ),
    );
    return ticket.copyWith(canManage: ticketAdmin);
  }

  @override
  Future<TicketMessage> sendTicketMessage(
    int ticketId,
    String content, {
    TicketAttachment? attachment,
  }) async {
    await _wait();
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    final id = _nextMessageId++;
    final message = TicketMessage(
      id: id,
      sender: _me.name,
      author: _me,
      isMine: true,
      fromAdmin: ticketAdmin,
      content: content,
      attachmentUrl: _demoAttachmentUrl(attachment, 'm$id'),
      createdAt: DateTime.now(),
    );
    if (index >= 0) {
      final t = _tickets[index];
      _tickets[index] = t.copyWith(
        messages: [...t.messages, message],
        messagesCount: t.messages.length + 1,
        updatedAt: DateTime.now(),
      );
    }
    return message;
  }

  @override
  Future<Ticket> updateTicket(int ticketId, TicketUpdate update) async {
    await _wait();
    if (!ticketAdmin) {
      throw const ApiException(
        statusCode: 403,
        code: 'forbidden',
        detail: "Vous n'avez pas la permission d'effectuer cette action.",
      );
    }
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    if (index < 0) {
      throw const ApiException(statusCode: 404, code: 'not_found');
    }
    var t = _tickets[index];
    final status = update.status;
    if (status != null) {
      t = t.copyWith(
        status: status,
        statusLabel: TicketChoices.labelOf(_choices.statuses, status),
      );
    }
    if (update.assigneeChanged) {
      final admins = await fetchTicketAdmins();
      final assignee = update.assignedTo == null
          ? null
          : admins.where((a) => a.id == update.assignedTo).firstOrNull;
      t = t.copyWith(assignedTo: () => assignee);
    }
    _tickets[index] = t = t.copyWith(updatedAt: DateTime.now());
    return t.copyWith(messages: const []);
  }

  @override
  Future<List<TicketPerson>> fetchTicketAdmins() async {
    await _wait();
    return [
      for (final json in asMapList(demoTicketAdminsJson()['admins']))
        ?TicketPerson.fromJsonOrNull(json),
    ];
  }
}
