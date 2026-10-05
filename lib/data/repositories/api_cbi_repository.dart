import 'dart:convert';
import 'dart:typed_data';

import '../../core/api/api_client.dart';
import '../../core/storage/catalog_cache_store.dart';
import '../../core/utils/json.dart';
import '../models/catalog.dart';
import '../models/history.dart';
import '../models/mobile_layout.dart';
import '../models/notification.dart';
import '../models/remote_config.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import 'cbi_repository.dart';

/// [CbiRepository] backed by the CBI mobile API v1.
class ApiCbiRepository implements CbiRepository {
  ApiCbiRepository(this._client, {CatalogCacheStore? cache}) : _cache = cache; // ignore: prefer_initializing_formals

  final ApiClient _client;
  final CatalogCacheStore? _cache;

  String? _catalogEtag;
  Catalog? _cachedCatalog;

  @override
  set token(String? value) {
    if (value != _client.token) {
      _catalogEtag = null;
      _cachedCatalog = null;
    }
    _client.token = value;
  }

  @override
  Future<RemoteConfig> fetchConfig() async =>
      RemoteConfig.fromJson((await _client.get('config/')).json);

  @override
  Future<LoginResult> login({
    required String username,
    required String password,
    String? device,
    String? appVersion,
  }) async {
    // Never with the (possibly expired) token: a 401 here means bad
    // credentials, not an expired session.
    final response = await _client.post(
      'auth/login/',
      authenticated: false,
      body: {
        'username': username,
        'password': password,
        'device': ?device,
        'app_version': ?appVersion,
      },
    );
    return LoginResult.fromJson(response.json);
  }

  @override
  Future<void> logout() async =>
      _client.post('auth/logout/', renewOn401: false);

  @override
  Future<User> fetchMe() async => User.fromJson((await _client.get('me/')).json);

  @override
  Future<Uint8List?> fetchPhoto(String photoUrl) => _client.getBytes(photoUrl);

  @override
  Future<Catalog?> cachedCatalog() async {
    if (_cachedCatalog != null) return _cachedCatalog;
    final entry = await _cache?.read();
    if (entry == null) return null;
    try {
      final decoded = jsonDecode(entry.json);
      if (decoded is! Map<String, dynamic>) return null;
      // Only adopt it if no fresh copy arrived meanwhile.
      if (_cachedCatalog == null) {
        _cachedCatalog = Catalog.fromJson(decoded);
        _catalogEtag = entry.etag;
      }
      return _cachedCatalog;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearCatalogCache() async {
    _catalogEtag = null;
    _cachedCatalog = null;
    await _cache?.clear();
  }

  @override
  Future<Catalog> fetchCatalog({bool force = false}) async {
    if (!force && _cachedCatalog == null) await cachedCatalog();
    final etag = force ? null : _catalogEtag;
    final response = await _client.get(
      'catalog/',
      headers: etag == null || _cachedCatalog == null
          ? null
          : {'If-None-Match': etag},
    );
    if (response.isNotModified && _cachedCatalog != null) {
      return _cachedCatalog!;
    }
    final catalog = Catalog.fromJson(response.json);
    _catalogEtag = response.headers['etag'];
    _cachedCatalog = catalog;
    await _cache?.write(
      CachedCatalogEntry(json: jsonEncode(response.json), etag: _catalogEtag),
    );
    return catalog;
  }

  @override
  Future<ReportOpening> openReport(int reportId) async =>
      ReportOpening.fromJson((await _client.post('reports/$reportId/open/')).json);

  @override
  Future<MobileLayout> fetchMobileLayout(int reportId) async =>
      MobileLayout.fromJson(
        (await _client.get('reports/$reportId/mobile-layout/')).json,
      );

  @override
  Future<void> closeReport(
    int reportId, {
    required int viewId,
    required int durationSeconds,
  }) => _client.post(
    'reports/$reportId/close/',
    body: {'view_id': viewId, 'duration_seconds': durationSeconds},
  );

  @override
  Future<bool> setFavorite(int reportId, bool favorite) async {
    final path = 'favorites/$reportId/';
    final response = favorite
        ? await _client.put(path)
        : await _client.delete(path);
    // The cached catalog is stale now; force a full fetch next time.
    _catalogEtag = null;
    return asBool(response.json['favorite'], favorite);
  }

  @override
  Future<NotificationsPage> fetchNotifications({
    int? after,
    int limit = 50,
  }) async => NotificationsPage.fromJson(
    (await _client.get(
      'notifications/',
      query: {'after': ?after?.toString(), 'limit': '$limit'},
    )).json,
  );

  @override
  Future<UnreadCount> fetchUnreadCount() async =>
      UnreadCount.fromJson((await _client.get('notifications/unread-count/')).json);

  @override
  Future<int> markNotificationRead(int id) async =>
      asInt((await _client.post('notifications/$id/read/')).json['unread_count']);

  @override
  Future<int> markAllNotificationsRead() async =>
      asInt((await _client.post('notifications/read-all/')).json['unread_count']);

  @override
  Future<List<HistoryItem>> fetchMyHistory({int days = 30}) async =>
      asMapList(
        (await _client.get('history/', query: {'days': '$days'})).json['history'],
      ).map(HistoryItem.fromJson).toList();

  @override
  Future<HistoryUsersPage> fetchHistoryUsers({
    String q = '',
    String company = '',
    int limit = 50,
    int offset = 0,
  }) async => HistoryUsersPage.fromJson(
    (await _client.get(
      'history/users/',
      query: {
        'q': q,
        'company': company,
        'limit': '$limit',
        'offset': '$offset',
      },
    )).json,
  );

  @override
  Future<UserHistory> fetchUserHistory(int userId, {int days = 30}) async =>
      UserHistory.fromJson(
        (await _client.get(
          'history/users/$userId/',
          query: {'days': '$days'},
        )).json,
      );

  @override
  Future<TicketChoices> fetchTicketChoices() async =>
      TicketChoices.fromJson((await _client.get('tickets/choices/')).json);

  @override
  Future<TicketList> fetchTickets({
    TicketFilter filter = TicketFilter.all,
  }) async {
    // The server ignores `assigned=me` for non-admins: always send it.
    final query = filter.query(isAdmin: true);
    return TicketList.fromJson(
      (await _client.get('tickets/', query: query.isEmpty ? null : query)).json,
    );
  }

  @override
  Future<Ticket> createTicket(NewTicket ticket) async => Ticket.fromJson(
    (await _client.postMultipart(
      'tickets/',
      fields: ticket.toFields(),
      files: _files(ticket.attachment),
    )).json,
  );

  @override
  Future<Ticket> fetchTicket(int id) async =>
      Ticket.fromJson((await _client.get('tickets/$id/')).json);

  @override
  Future<TicketMessage> sendTicketMessage(
    int ticketId,
    String content, {
    TicketAttachment? attachment,
  }) async => TicketMessage.fromJson(
    (await _client.postMultipart(
      'tickets/$ticketId/messages/',
      fields: {'content': content},
      files: _files(attachment),
    )).json,
  );

  @override
  Future<Ticket> updateTicket(int ticketId, TicketUpdate update) async =>
      Ticket.fromJson(
        (await _client.post(
          'tickets/$ticketId/update/',
          body: update.toJson(),
        )).json,
      );

  @override
  Future<List<TicketPerson>> fetchTicketAdmins() async => [
    for (final json in asMapList((await _client.get('tickets/admins/')).json['admins']))
      ?TicketPerson.fromJsonOrNull(json),
  ];

  static List<MultipartAttachment> _files(TicketAttachment? attachment) => [
    if (attachment != null)
      MultipartAttachment(
        field: 'attachment',
        bytes: attachment.bytes,
        filename: attachment.filename,
      ),
  ];
}
