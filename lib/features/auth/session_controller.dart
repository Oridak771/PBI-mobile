import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/storage/remembered_credentials_store.dart';
import '../../core/storage/session_store.dart';
import '../../data/models/user.dart';
import '../lock/app_lock_controller.dart';

enum SessionStatus { unknown, authenticated, unauthenticated }

class SessionState {
  const SessionState({
    this.status = SessionStatus.unknown,
    this.user,
    this.credentials,
    this.expired = false,
    this.passwordChanged = false,
  });

  final SessionStatus status;
  final User? user;
  final PbiCredentials? credentials;

  /// `true` when the session ended because the server answered `401`.
  final bool expired;

  /// `true` when the silent re-login was refused (`invalid_credentials`):
  /// the AD password changed since it was remembered.
  final bool passwordChanged;

  bool get isAuthenticated => status == SessionStatus.authenticated;
}

/// Owns the login state.
///
/// An authenticated `401` first triggers one silent re-login with the
/// remembered credentials ("Se souvenir de moi"); when that is impossible or
/// fails, the session is wiped (the app then goes back to the login screen,
/// see `CbiApp`).
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    ref.watch(apiClientProvider)
      ..onUnauthorized = _onUnauthorized
      ..reauthenticate = _silentRelogin;
    return const SessionState();
  }

  SessionStore get _store => ref.read(sessionStoreProvider);
  RememberedCredentialsStore get _remembered =>
      ref.read(rememberedCredentialsStoreProvider);

  /// Splash: restores a stored session and refreshes `me/`.
  /// Returns `true` when the user is logged in.
  Future<bool> restore() async {
    final stored = await _store.read();
    if (stored == null) {
      state = const SessionState(status: SessionStatus.unauthenticated);
      return false;
    }
    final repo = ref.read(repositoryProvider)..token = stored.token;
    try {
      final me = await repo.fetchMe();
      await _store.updateUser(me);
      // Re-read: a silent re-login may have refreshed the credentials.
      final current = await _store.read();
      state = SessionState(
        status: SessionStatus.authenticated,
        user: me,
        credentials: current?.credentials ?? stored.credentials,
      );
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // Already wiped by the client (possibly as "password changed").
        if (state.status != SessionStatus.unauthenticated) {
          await _wipe(expired: true);
        }
        return false;
      }
      return _useCached(stored, e);
    } on NetworkException catch (e) {
      return _useCached(stored, e);
    }
  }

  bool _useCached(StoredSession stored, Object error) {
    // Offline start: keep the cached profile, requests will retry later.
    if (stored.user == null) throw error;
    state = SessionState(
      status: SessionStatus.authenticated,
      user: stored.user,
      credentials: stored.credentials,
    );
    return true;
  }

  /// Logs in. With [remember] the username and password are kept on the
  /// device (they survive logout); without it, any remembered credentials are
  /// forgotten so a stale password is never used.
  Future<void> login({
    required String username,
    required String password,
    bool remember = true,
  }) async {
    final result = await _authenticate(username, password);
    if (remember) {
      await _remembered.save(username, password);
    } else {
      await _remembered.clear();
    }
    await _store.setLastUsername(username);
    _authenticated(result);
  }

  Future<LoginResult> _authenticate(String username, String password) async {
    final repo = ref.read(repositoryProvider);
    String? version;
    try {
      version = await ref.read(appVersionProvider.future);
    } catch (_) {
      version = null;
    }
    final result = await repo.login(
      username: username,
      password: password,
      device: _deviceDescription(),
      appVersion: version,
    );
    await _store.save(
      StoredSession(
        token: result.token,
        user: result.user,
        credentials: result.credentials,
        password: password,
      ),
    );
    repo.token = result.token;
    return result;
  }

  void _authenticated(LoginResult result) {
    state = SessionState(
      status: SessionStatus.authenticated,
      user: result.user,
      credentials: result.credentials,
    );
  }

  /// `ApiClient.reauthenticate`: the token was rejected (expired / revoked).
  /// Logs in again with the remembered credentials; `true` when a new token
  /// is set. Only one attempt runs at a time (see `ApiClient`).
  Future<bool> _silentRelogin() async {
    final saved = await _remembered.read();
    if (saved == null || !saved.hasPassword) return false;
    // With the lock on, never re-login behind the lock screen.
    await ref.read(appLockProvider.notifier).whenUnlocked();
    if (state.status == SessionStatus.unauthenticated) return false;
    try {
      final result = await _authenticate(saved.username, saved.password!);
      // At splash (status unknown) `restore` publishes the state itself.
      if (state.isAuthenticated) _authenticated(result);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401 && e.code == 'invalid_credentials') {
        // AD password changed: keep the username, drop the stale password.
        await _remembered.clearPassword();
        await _wipe(passwordChanged: true);
      }
      return false;
    } catch (_) {
      // Network, 429...: the normal 401 handling follows, nothing deleted.
      return false;
    }
  }

  /// Logs out. Remembered credentials and the lock settings are kept.
  Future<void> logout() async {
    final repo = ref.read(repositoryProvider);
    try {
      // Logout from the lock screen at cold start: the token is not set yet.
      if (!state.isAuthenticated) {
        final stored = await _store.read();
        if (stored != null) repo.token = stored.token;
      }
      await repo.logout();
    } catch (_) {
      // Offline logout still wipes the local session.
    }
    await _wipe();
  }

  /// Updates the password (and user) used for PBIRS NTLM challenges.
  /// Also refreshes the remembered password, when one is remembered.
  Future<void> updatePbiLogin(PbiCredentials credentials, String password) async {
    await _store.updatePbiLogin(credentials, password);
    await _remembered.updatePassword(password);
    state = SessionState(
      status: state.status,
      user: state.user,
      credentials: credentials,
    );
  }

  void _onUnauthorized() {
    if (state.status == SessionStatus.unauthenticated) return;
    _wipe(expired: true);
  }

  Future<void> _wipe({bool expired = false, bool passwordChanged = false}) async {
    final repo = ref.read(repositoryProvider)..token = null;
    state = SessionState(
      status: SessionStatus.unauthenticated,
      expired: expired || passwordChanged,
      passwordChanged: passwordChanged,
    );
    ref.read(appLockProvider.notifier).release();
    await _store.clear();
    // The next user must not see this user's catalog.
    try {
      await repo.clearCatalogCache();
    } catch (_) {}
  }

  static String _deviceDescription() {
    try {
      final os = Platform.operatingSystem;
      final name = os.isEmpty ? '' : os[0].toUpperCase() + os.substring(1);
      return '$name ${Platform.operatingSystemVersion}'.trim();
    } catch (_) {
      return 'Android';
    }
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
