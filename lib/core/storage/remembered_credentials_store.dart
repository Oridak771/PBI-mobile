import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Login saved by "Se souvenir de moi".
class RememberedCredentials {
  const RememberedCredentials({required this.username, this.password});

  /// Username exactly as sent to `auth/login/` (email or AD 2000).
  final String username;

  /// AD password; `null` after the server rejected it (password changed).
  final String? password;

  bool get hasPassword => password != null && password!.isNotEmpty;
}

/// Credentials remembered on this device.
///
/// Stored under their own keys, separate from the session: they survive
/// logout and `401` (see `SessionStore.clear`), so the user can log in again
/// with a fingerprint or be re-logged silently when the token expires.
abstract class RememberedCredentialsStore {
  Future<RememberedCredentials?> read();
  Future<void> save(String username, String password);

  /// Replaces the password, only when credentials are remembered.
  Future<void> updatePassword(String password);

  /// Drops the password but keeps the username (AD password changed).
  Future<void> clearPassword();

  /// Forgets everything ("Se souvenir de moi" unchecked at login).
  Future<void> clear();
}

/// `flutter_secure_storage` (Android Keystore-backed, device-only).
class SecureRememberedCredentialsStore implements RememberedCredentialsStore {
  SecureRememberedCredentialsStore({FlutterSecureStorage? secure})
    : _secure = secure ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  static const kUsername = 'remembered_username';
  static const kPassword = 'remembered_password';

  @override
  Future<RememberedCredentials?> read() async {
    final username = await _secure.read(key: kUsername);
    if (username == null || username.isEmpty) return null;
    return RememberedCredentials(
      username: username,
      password: await _secure.read(key: kPassword),
    );
  }

  @override
  Future<void> save(String username, String password) async {
    await _secure.write(key: kUsername, value: username);
    await _secure.write(key: kPassword, value: password);
  }

  @override
  Future<void> updatePassword(String password) async {
    final current = await read();
    if (current == null || !current.hasPassword) return;
    await _secure.write(key: kPassword, value: password);
  }

  @override
  Future<void> clearPassword() => _secure.delete(key: kPassword);

  @override
  Future<void> clear() async {
    await _secure.delete(key: kUsername);
    await _secure.delete(key: kPassword);
  }
}

/// In-memory store (tests and demo mode).
class MemoryRememberedCredentialsStore implements RememberedCredentialsStore {
  MemoryRememberedCredentialsStore([this._value]);

  RememberedCredentials? _value;

  @override
  Future<RememberedCredentials?> read() async => _value;

  @override
  Future<void> save(String username, String password) async =>
      _value = RememberedCredentials(username: username, password: password);

  @override
  Future<void> updatePassword(String password) async {
    final current = _value;
    if (current == null || !current.hasPassword) return;
    _value = RememberedCredentials(username: current.username, password: password);
  }

  @override
  Future<void> clearPassword() async {
    final current = _value;
    if (current != null) _value = RememberedCredentials(username: current.username);
  }

  @override
  Future<void> clear() async => _value = null;
}
