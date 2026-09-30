import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/user.dart';

/// Everything persisted for a logged-in user.
class StoredSession {
  const StoredSession({
    required this.token,
    this.user,
    this.credentials,
    this.password,
  });

  final String token;
  final User? user;
  final PbiCredentials? credentials;

  /// AD password, only used to answer PBIRS NTLM challenges.
  final String? password;
}

/// Persistence of the session.
///
/// Secrets (token, user, NTLM credentials, password) live in
/// `flutter_secure_storage` (Android Keystore). Non-sensitive preferences
/// (last username, last seen notification id) live in shared preferences.
abstract class SessionStore {
  Future<StoredSession?> read();
  Future<void> save(StoredSession session);
  Future<void> updateUser(User user);
  Future<void> updatePbiLogin(PbiCredentials credentials, String password);

  /// Wipes the session (keeps the last username, like the legacy app).
  Future<void> clear();

  Future<String?> lastUsername();
  Future<void> setLastUsername(String username);

  Future<int> lastSeenNotificationId();
  Future<void> setLastSeenNotificationId(int id);
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? secure})
    : _secure = secure ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  static const _kToken = 'token';
  static const _kUser = 'user';
  static const _kCredentials = 'pbi_credentials';
  static const _kPassword = 'pbi_password';
  static const _kLastUsername = 'last_username';
  static const _kLastSeenNotification = 'notifications_last_seen_id';

  @override
  Future<StoredSession?> read() async {
    final token = await _secure.read(key: _kToken);
    if (token == null || token.isEmpty) return null;
    final user = await _secure.read(key: _kUser);
    final credentials = await _secure.read(key: _kCredentials);
    return StoredSession(
      token: token,
      user: user == null ? null : User.fromJson(jsonDecode(user) as Map<String, dynamic>),
      credentials: credentials == null
          ? null
          : PbiCredentials.fromJson(jsonDecode(credentials) as Map<String, dynamic>),
      password: await _secure.read(key: _kPassword),
    );
  }

  @override
  Future<void> save(StoredSession session) async {
    await _secure.write(key: _kToken, value: session.token);
    if (session.user != null) await updateUser(session.user!);
    if (session.credentials != null) {
      await _secure.write(
        key: _kCredentials,
        value: jsonEncode(session.credentials!.toJson()),
      );
    }
    if (session.password != null) {
      await _secure.write(key: _kPassword, value: session.password);
    }
  }

  @override
  Future<void> updateUser(User user) =>
      _secure.write(key: _kUser, value: jsonEncode(user.toJson()));

  @override
  Future<void> updatePbiLogin(PbiCredentials credentials, String password) async {
    await _secure.write(
      key: _kCredentials,
      value: jsonEncode(credentials.toJson()),
    );
    await _secure.write(key: _kPassword, value: password);
  }

  @override
  Future<void> clear() async {
    for (final key in [_kToken, _kUser, _kCredentials, _kPassword]) {
      await _secure.delete(key: key);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastSeenNotification);
  }

  @override
  Future<String?> lastUsername() async =>
      (await SharedPreferences.getInstance()).getString(_kLastUsername);

  @override
  Future<void> setLastUsername(String username) async =>
      (await SharedPreferences.getInstance()).setString(_kLastUsername, username);

  @override
  Future<int> lastSeenNotificationId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // may have been written by the background isolate
    return prefs.getInt(_kLastSeenNotification) ?? 0;
  }

  @override
  Future<void> setLastSeenNotificationId(int id) async =>
      (await SharedPreferences.getInstance()).setInt(_kLastSeenNotification, id);
}

/// In-memory store (tests and demo mode).
class MemorySessionStore implements SessionStore {
  MemorySessionStore({StoredSession? session, String? lastUsername}) {
    _session = session;
    _lastUsername = lastUsername;
  }

  StoredSession? _session;
  String? _lastUsername;
  int _lastSeen = 0;

  @override
  Future<StoredSession?> read() async => _session;

  @override
  Future<void> save(StoredSession session) async => _session = session;

  @override
  Future<void> updateUser(User user) async {
    final s = _session;
    if (s != null) {
      _session = StoredSession(
        token: s.token,
        user: user,
        credentials: s.credentials,
        password: s.password,
      );
    }
  }

  @override
  Future<void> updatePbiLogin(PbiCredentials credentials, String password) async {
    final s = _session;
    if (s != null) {
      _session = StoredSession(
        token: s.token,
        user: s.user,
        credentials: credentials,
        password: password,
      );
    }
  }

  @override
  Future<void> clear() async {
    _session = null;
    _lastSeen = 0;
  }

  @override
  Future<String?> lastUsername() async => _lastUsername;

  @override
  Future<void> setLastUsername(String username) async => _lastUsername = username;

  @override
  Future<int> lastSeenNotificationId() async => _lastSeen;

  @override
  Future<void> setLastSeenNotificationId(int id) async => _lastSeen = id;
}
