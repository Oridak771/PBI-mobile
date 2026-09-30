import '../../core/utils/json.dart';

/// One report consultation.
class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.reportId,
    required this.reportName,
    this.location = '',
    this.openedAt,
    this.durationSeconds = 0,
    this.source = 'mobile',
  });

  factory HistoryItem.fromJson(Json json) => HistoryItem(
    id: asInt(json['id']),
    reportId: asInt(json['report_id']),
    reportName: asString(json['report_name']),
    location: asString(json['location']),
    openedAt: asDate(json['opened_at']),
    durationSeconds: asInt(json['duration_seconds']),
    source: asString(json['source'], 'mobile'),
  );

  final int id;
  final int reportId;
  final String reportName;
  final String location;
  final DateTime? openedAt;
  final int durationSeconds;
  final String source;

  /// `location / report_name` line of the legacy rows.
  String get path =>
      location.isEmpty ? reportName : '$location / $reportName';
}

/// User block of the history screens.
class HistoryUser {
  const HistoryUser({
    required this.id,
    required this.name,
    this.initials = '',
    this.description = '',
    this.company = '',
    this.photoUrl,
    this.avatarColor,
  });

  factory HistoryUser.fromJson(Json json) => HistoryUser(
    id: asInt(json['id']),
    name: asString(json['name']),
    initials: asString(json['initials']),
    description: asString(json['description']),
    company: asString(json['company']),
    photoUrl: asStringOrNull(json['photo_url']),
    avatarColor: asStringOrNull(json['avatar_color']),
  );

  final int id;
  final String name;
  final String initials;
  final String description;
  final String company;
  final String? photoUrl;
  final String? avatarColor;
}

class HistoryUserEntry {
  const HistoryUserEntry({required this.user, this.last});

  factory HistoryUserEntry.fromJson(Json json) {
    final last = asMap(json['last']);
    return HistoryUserEntry(
      user: HistoryUser.fromJson(asMap(json['user'])),
      last: last.isEmpty ? null : HistoryItem.fromJson(last),
    );
  }

  final HistoryUser user;
  final HistoryItem? last;
}

/// `GET history/users/`.
class HistoryUsersPage {
  const HistoryUsersPage({this.count = 0, this.results = const []});

  factory HistoryUsersPage.fromJson(Json json) => HistoryUsersPage(
    count: asInt(json['count']),
    results: asMapList(json['results']).map(HistoryUserEntry.fromJson).toList(),
  );

  final int count;
  final List<HistoryUserEntry> results;
}

/// `GET history/users/<id>/`.
class UserHistory {
  const UserHistory({required this.user, this.history = const []});

  factory UserHistory.fromJson(Json json) => UserHistory(
    user: HistoryUser.fromJson(asMap(json['user'])),
    history: asMapList(json['history']).map(HistoryItem.fromJson).toList(),
  );

  final HistoryUser user;
  final List<HistoryItem> history;
}
