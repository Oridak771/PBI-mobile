import '../../core/utils/json.dart';

/// `GET catalog/` – everything the home, tabs, report lists and favorites
/// screens need.
class Catalog {
  const Catalog({
    this.generatedAt,
    this.servers = const [],
    this.sections = const [],
    this.reports = const {},
    this.favoriteIds = const {},
    this.unreadNotificationCount = 0,
  });

  factory Catalog.fromJson(Json json) {
    final favoriteIds = asIntList(json['favorite_ids']).toSet();
    final reports = <int, Report>{};
    asMap(json['reports']).forEach((key, value) {
      final report = Report.fromJson(asMap(value));
      final id = report.id != 0 ? report.id : int.tryParse(key) ?? 0;
      reports[id] = report.id == id ? report : report.copyWith(id: id);
      if (report.favorite) favoriteIds.add(id);
    });
    return Catalog(
      generatedAt: asDate(json['generated_at']),
      servers: asMapList(json['servers']).map(PbiServer.fromJson).toList(),
      sections: asMapList(
        json['sections'],
      ).map(CatalogSection.fromJson).where((s) => s.groups.isNotEmpty).toList(),
      reports: reports,
      favoriteIds: favoriteIds,
      unreadNotificationCount: asInt(json['unread_notification_count']),
    );
  }

  final DateTime? generatedAt;
  final List<PbiServer> servers;
  final List<CatalogSection> sections;
  final Map<int, Report> reports;
  final Set<int> favoriteIds;
  final int unreadNotificationCount;

  bool get isEmpty => sections.isEmpty;

  List<CatalogGroup> get allGroups => [for (final s in sections) ...s.groups];

  /// Legacy skip rule: exactly one group in the whole catalog → open its tabs
  /// directly.
  CatalogGroup? get singleGroup {
    final groups = allGroups;
    return groups.length == 1 ? groups.single : null;
  }

  /// Hosts the WebView may send credentials to (lower case).
  Set<String> get serverHosts => {
    for (final s in servers)
      if (s.host.isNotEmpty) s.host.toLowerCase(),
  };

  /// Host of `servers[id]` (lower case), `null` when unknown.
  String? hostForServer(int? id) {
    for (final s in servers) {
      if (s.id == id && s.host.isNotEmpty) return s.host.toLowerCase();
    }
    return null;
  }

  bool isFavorite(int reportId) => favoriteIds.contains(reportId);

  /// Section holding [group] (`null` when unknown).
  CatalogSection? sectionOf(CatalogGroup group) {
    for (final s in sections) {
      if (s.groups.any((g) => g.key == group.key)) return s;
    }
    return null;
  }

  /// Distinct known reports of [group], in tab order, each with the first
  /// tab listing it.
  List<(Report, GroupTab)> reportsOfGroup(CatalogGroup group) {
    final seen = <int>{};
    return [
      for (final tab in group.tabs)
        for (final id in tab.reportIds)
          if (reports[id] != null && seen.add(id)) (reports[id]!, tab),
    ];
  }

  /// Number of distinct known reports of [group].
  int reportCountOf(CatalogGroup group) => reportsOfGroup(group).length;

  /// Number of known reports of [tab].
  int reportCountOfTab(GroupTab tab) => reportsFor(tab).length;

  /// Reports of a tab, in the tab's order, skipping unknown ids.
  List<Report> reportsFor(GroupTab tab) => [
    for (final id in tab.reportIds)
      if (reports[id] != null) reports[id]!,
  ];

  /// Favourite reports sorted by location then name (like `GET favorites/`).
  List<Report> get favorites {
    final list = [
      for (final id in favoriteIds)
        if (reports[id] != null) reports[id]!,
    ];
    list.sort(compareByLocationThenName);
    return list;
  }

  Catalog withFavorite(int reportId, bool favorite) {
    final ids = {...favoriteIds};
    favorite ? ids.add(reportId) : ids.remove(reportId);
    final report = reports[reportId];
    return copyWith(
      favoriteIds: ids,
      reports: report == null
          ? reports
          : {...reports, reportId: report.copyWith(favorite: favorite)},
    );
  }

  Catalog copyWith({
    Map<int, Report>? reports,
    Set<int>? favoriteIds,
    int? unreadNotificationCount,
  }) => Catalog(
    generatedAt: generatedAt,
    servers: servers,
    sections: sections,
    reports: reports ?? this.reports,
    favoriteIds: favoriteIds ?? this.favoriteIds,
    unreadNotificationCount:
        unreadNotificationCount ?? this.unreadNotificationCount,
  );
}

int compareByLocationThenName(Report a, Report b) {
  final byLocation = a.location.toLowerCase().compareTo(
    b.location.toLowerCase(),
  );
  return byLocation != 0
      ? byLocation
      : a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// A PBIRS server (`catalog.servers[]`).
class PbiServer {
  const PbiServer({
    required this.id,
    this.name = '',
    this.baseUrl = '',
    this.host = '',
    this.scheme = 'http',
  });

  factory PbiServer.fromJson(Json json) {
    final baseUrl = asString(json['base_url']);
    return PbiServer(
      id: asInt(json['id']),
      name: asString(json['name']),
      baseUrl: baseUrl,
      host: asString(json['host'], Uri.tryParse(baseUrl)?.host ?? ''),
      scheme: asString(json['scheme'], 'http'),
    );
  }

  final int id;
  final String name;
  final String baseUrl;
  final String host;
  final String scheme;
}

enum SectionLayout { row, grid }

class CatalogSection {
  const CatalogSection({
    required this.key,
    required this.title,
    this.layout = SectionLayout.row,
    this.groups = const [],
  });

  factory CatalogSection.fromJson(Json json) => CatalogSection(
    key: asString(json['key']),
    title: asString(json['title']),
    layout: json['layout'] == 'grid' ? SectionLayout.grid : SectionLayout.row,
    groups: asMapList(json['groups'])
        .map(CatalogGroup.fromJson)
        .where((g) => g.tabs.isNotEmpty)
        .toList(),
  );

  final String key;
  final String title;
  final SectionLayout layout;
  final List<CatalogGroup> groups;

  /// `consolide`: the home row shows the single group's **tabs** as cards.
  bool get isConsolide => key == 'consolide';
}

class CatalogGroup {
  const CatalogGroup({
    required this.key,
    required this.name,
    this.code = '',
    this.parent,
    this.logoUrl,
    this.tabs = const [],
  });

  factory CatalogGroup.fromJson(Json json) => CatalogGroup(
    key: asString(json['key']),
    name: asString(json['name']),
    code: asString(json['code']),
    parent: asStringOrNull(json['parent']),
    logoUrl: asStringOrNull(json['logo_url']),
    tabs: asMapList(json['tabs'])
        .map(GroupTab.fromJson)
        .where((t) => t.reportIds.isNotEmpty)
        .toList(),
  );

  final String key;
  final String name;
  final String code;
  final String? parent;

  /// Pôle / société logo, relative to `API_BASE_URL`
  /// (`/mobile/v1/metadata/9/logo/?v=…`). Versioned: cacheable forever.
  final String? logoUrl;
  final List<GroupTab> tabs;

  /// Text drawn over the tile when no image is registered.
  String get label => (code.isEmpty ? name : code).toUpperCase();
}

class GroupTab {
  const GroupTab({
    required this.key,
    required this.name,
    this.code = '',
    this.reportIds = const [],
  });

  factory GroupTab.fromJson(Json json) => GroupTab(
    key: asString(json['key']),
    name: asString(json['name']),
    code: asString(json['code']),
    reportIds: asIntList(json['report_ids']),
  );

  final String key;
  final String name;
  final String code;
  final List<int> reportIds;

  /// Tab bar label: code in upper case, or the name when there is no code.
  String get label => code.isEmpty ? name : code.toUpperCase();
}

class Report {
  const Report({
    required this.id,
    required this.name,
    this.description = '',
    this.location = '',
    this.serverId,
    this.embedUrl = '',
    this.phone,
    this.modifiedAt,
    this.favorite = false,
    this.hasMobileLayout = false,
  });

  factory Report.fromJson(Json json) => Report(
    id: asInt(json['id']),
    name: asString(json['name']),
    description: asString(json['description']),
    location: asString(json['location']),
    serverId: asIntOrNull(json['server_id']),
    embedUrl: asString(json['embed_url']),
    phone: PhoneEdition.tryParse(json['phone']),
    modifiedAt: asDate(json['modified_at']),
    favorite: asBool(json['favorite']),
    hasMobileLayout: asBool(json['has_mobile_layout']),
  );

  final int id;
  final String name;
  final String description;
  final String location;
  final int? serverId;
  final String embedUrl;

  /// Portrait "phone" edition linked by an admin, `null` when none.
  final PhoneEdition? phone;
  final DateTime? modifiedAt;
  final bool favorite;

  /// `has_mobile_layout`: the .pbix has a Power BI phone layout (the viewer
  /// can show the "Vue mobile"). Defaults to `false`.
  final bool hasMobileLayout;

  bool get hasPhoneEdition => phone != null;

  /// Shown as "Vue mobile" in the lists: a phone layout or a phone edition.
  bool get hasMobileView => hasMobileLayout || phone != null;

  Report copyWith({int? id, bool? favorite}) => Report(
    id: id ?? this.id,
    name: name,
    description: description,
    location: location,
    serverId: serverId,
    embedUrl: embedUrl,
    phone: phone,
    modifiedAt: modifiedAt,
    favorite: favorite ?? this.favorite,
    hasMobileLayout: hasMobileLayout,
  );
}

/// `report.phone`: the portrait edition of a report (a separate PBIRS
/// report, never listed on its own).
class PhoneEdition {
  const PhoneEdition({required this.id, this.serverId, required this.embedUrl});

  /// `null` for a missing / malformed object or an empty `embed_url`.
  static PhoneEdition? tryParse(Object? value) {
    if (value is! Map) return null;
    final json = asMap(value);
    final url = asString(json['embed_url']).trim();
    if (url.isEmpty) return null;
    return PhoneEdition(
      id: asInt(json['id']),
      serverId: asIntOrNull(json['server_id']),
      embedUrl: url,
    );
  }

  final int id;
  final int? serverId;
  final String embedUrl;
}

/// `POST reports/<id>/open/`.
class ReportOpening {
  const ReportOpening({
    required this.viewId,
    required this.embedUrl,
    this.server,
    this.report,
  });

  factory ReportOpening.fromJson(Json json) {
    final server = asMap(json['server']);
    final report = asMap(json['report']);
    return ReportOpening(
      viewId: asInt(json['view_id']),
      embedUrl: asString(json['embed_url']),
      server: server.isEmpty ? null : PbiServer.fromJson(server),
      report: report.isEmpty ? null : Report.fromJson(report),
    );
  }

  final int viewId;
  final String embedUrl;
  final PbiServer? server;
  final Report? report;
}
