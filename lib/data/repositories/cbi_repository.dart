import 'dart:typed_data';

import '../models/catalog.dart';
import '../models/history.dart';
import '../models/mobile_layout.dart';
import '../models/notification.dart';
import '../models/remote_config.dart';
import '../models/ticket.dart';
import '../models/user.dart';

/// Every call the app makes to the CBI mobile API v1
/// (`<API_BASE_URL>/mobile/v1/`, see CBI/docs/MOBILE_API.md).
///
/// Implemented by [ApiCbiRepository] (network) and [DemoCbiRepository]
/// (fixtures, `--dart-define=ENABLE_DEMO_MODE=true`).
abstract class CbiRepository {
  /// Sets the Bearer token used by authenticated calls.
  set token(String? value);

  // Public
  Future<RemoteConfig> fetchConfig();
  Future<LoginResult> login({
    required String username,
    required String password,
    String? device,
    String? appVersion,
  });

  // Session
  Future<void> logout();
  Future<User> fetchMe();

  /// Photo bytes for `me/photo/` or any `photo_url`; `null` when absent.
  Future<Uint8List?> fetchPhoto(String photoUrl);

  // Catalog & reports
  /// `GET catalog/`, using `If-None-Match` / `304` with the last ETag.
  Future<Catalog> fetchCatalog({bool force = false});

  /// Last catalog saved on the device (shown at launch while [fetchCatalog]
  /// refreshes it), `null` when there is none.
  Future<Catalog?> cachedCatalog();

  /// Forgets the saved catalog (session ended).
  Future<void> clearCatalogCache();
  Future<ReportOpening> openReport(int reportId);

  /// `GET reports/<id>/mobile-layout/`: the Power BI phone layout. The first
  /// call for a report may take several seconds (the backend downloads the
  /// .pbix), later ones are served from the backend cache.
  Future<MobileLayout> fetchMobileLayout(int reportId);
  Future<void> closeReport(
    int reportId, {
    required int viewId,
    required int durationSeconds,
  });

  /// `PUT` (true) / `DELETE` (false) `favorites/<id>/`; returns the new state.
  Future<bool> setFavorite(int reportId, bool favorite);

  // Notifications
  Future<NotificationsPage> fetchNotifications({int? after, int limit = 50});
  Future<UnreadCount> fetchUnreadCount();

  /// Returns the new unread count.
  Future<int> markNotificationRead(int id);
  Future<int> markAllNotificationsRead();

  // History
  Future<List<HistoryItem>> fetchMyHistory({int days = 30});
  Future<HistoryUsersPage> fetchHistoryUsers({
    String q = '',
    String company = '',
    int limit = 50,
    int offset = 0,
  });
  Future<UserHistory> fetchUserHistory(int userId, {int days = 30});

  // Tickets (the platform's ticket system)
  /// `GET tickets/choices/`.
  Future<TicketChoices> fetchTicketChoices();

  /// `GET tickets/?status=&assigned=me`.
  Future<TicketList> fetchTickets({TicketFilter filter = TicketFilter.all});

  /// `POST tickets/` (multipart, optional image). A `400` carries the form
  /// errors in [ApiException.errors].
  Future<Ticket> createTicket(NewTicket ticket);

  /// `GET tickets/<id>/`: ticket + messages + `can_manage`.
  Future<Ticket> fetchTicket(int id);

  /// `POST tickets/<id>/messages/` (multipart, optional image).
  Future<TicketMessage> sendTicketMessage(
    int ticketId,
    String content, {
    TicketAttachment? attachment,
  });

  /// `POST tickets/<id>/update/` (admins): status and/or assignee.
  Future<Ticket> updateTicket(int ticketId, TicketUpdate update);

  /// `GET tickets/admins/` (admins): assignable users.
  Future<List<TicketPerson>> fetchTicketAdmins();
}
