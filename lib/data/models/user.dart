import '../../core/utils/json.dart';

/// `GET me/` (also `user` in the login response).
class User {
  const User({
    required this.id,
    required this.username,
    required this.name,
    this.initials = '',
    this.email = '',
    this.ad2000 = '',
    this.role = 'user',
    this.isAdmin = false,
    this.direction = '',
    this.pole = '',
    this.company = '',
    this.description = '',
    this.photoUrl,
    this.avatarColor,
    this.permissions = const {},
  });

  factory User.fromJson(Json json) => User(
    id: asInt(json['id']),
    username: asString(json['username']),
    name: asString(json['name']),
    initials: asString(json['initials']),
    email: asString(json['email']),
    ad2000: asString(json['ad2000']),
    role: asString(json['role'], 'user'),
    isAdmin: asBool(json['is_admin']),
    direction: asString(json['direction']),
    pole: asString(json['pole']),
    company: asString(json['company']),
    description: asString(json['description']),
    photoUrl: asStringOrNull(json['photo_url']),
    avatarColor: asStringOrNull(json['avatar_color']),
    permissions: asMap(
      json['permissions'],
    ).map((key, value) => MapEntry(key, asBool(value))),
  );

  final int id;
  final String username;
  final String name;
  final String initials;
  final String email;
  final String ad2000;
  final String role;
  final bool isAdmin;
  final String direction;
  final String pole;
  final String company;
  final String description;
  final String? photoUrl;
  final String? avatarColor;
  final Map<String, bool> permissions;

  Json toJson() => {
    'id': id,
    'username': username,
    'name': name,
    'initials': initials,
    'email': email,
    'ad2000': ad2000,
    'role': role,
    'is_admin': isAdmin,
    'direction': direction,
    'pole': pole,
    'company': company,
    'description': description,
    'photo_url': photoUrl,
    'avatar_color': avatarColor,
    'permissions': permissions,
  };
}

/// `credentials` of the login response: which `DOMAIN\username` to use when
/// answering PBIRS NTLM challenges.
class PbiCredentials {
  const PbiCredentials({required this.domain, required this.username});

  factory PbiCredentials.fromJson(Json json) => PbiCredentials(
    domain: asString(json['domain']),
    username: asString(json['username']),
  );

  /// Parses `DOMAIN\user` (or a bare `user`).
  factory PbiCredentials.parse(String value) {
    final v = value.trim();
    final i = v.indexOf(r'\');
    return i < 0
        ? PbiCredentials(domain: '', username: v)
        : PbiCredentials(
            domain: v.substring(0, i),
            username: v.substring(i + 1),
          );
  }

  final String domain;
  final String username;

  /// `DOMAIN\username` as sent in the NTLM handshake.
  String get ntlmUser => domain.isEmpty ? username : '$domain\\$username';

  Json toJson() => {'domain': domain, 'username': username};
}

/// `POST auth/login/` response.
class LoginResult {
  const LoginResult({
    required this.token,
    required this.user,
    required this.credentials,
    this.expiresAt,
  });

  factory LoginResult.fromJson(Json json) => LoginResult(
    token: asString(json['token']),
    expiresAt: asDate(json['expires_at']),
    user: User.fromJson(asMap(json['user'])),
    credentials: PbiCredentials.fromJson(asMap(json['credentials'])),
  );

  final String token;
  final DateTime? expiresAt;
  final User user;
  final PbiCredentials credentials;
}
