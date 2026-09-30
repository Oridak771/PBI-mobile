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

  bool isFavorite(int reportId) => favoriteIds.contains(reportId);

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
    this.tabs = const [],
  });

  factory CatalogGroup.fromJson(Json json) => CatalogGroup(
    key: asString(json['key']),
    name: asString(json['name']),
    code: asString(json['code']),
    parent: asStringOrNull(json['parent']),
    tabs: asMapList(json['tabs'])
        .map(GroupTab.fromJson)
        .where((t) => t.reportIds.isNotEmpty)
        .toList(),
  );

  final String key;
  final String name;
  final String code;
  final String? parent;
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
    this.modifiedAt,
    this.favorite = false,
  });

  factory Report.fromJson(Json json) => Report(
    id: asInt(json['id']),
    name: asString(json['name']),
    description: asString(json['description']),
    location: asString(json['location']),
    serverId: asIntOrNull(json['server_id']),
    embedUrl: asString(json['embed_url']),
    modifiedAt: asDate(json['modified_at']),
    favorite: asBool(json['favorite']),
  );

  final int id;
  final String name;
  final String description;
  final String location;
  final int? serverId;
  final String embedUrl;
  final DateTime? modifiedAt;
  final bool favorite;

  Report copyWith({int? id, bool? favorite}) => Report(
    id: id ?? this.id,
    name: name,
    description: description,
    location: location,
    serverId: serverId,
    embedUrl: embedUrl,
    modifiedAt: modifiedAt,
    favorite: favorite ?? this.favorite,
  );
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
