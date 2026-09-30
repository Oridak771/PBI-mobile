import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/storage/session_store.dart';
import '../../data/models/user.dart';

enum SessionStatus { unknown, authenticated, unauthenticated }

class SessionState {
  const SessionState({
    this.status = SessionStatus.unknown,
    this.user,
    this.credentials,
    this.expired = false,
  });

  final SessionStatus status;
  final User? user;
  final PbiCredentials? credentials;

  /// `true` when the session ended because the server answered `401`.
  final bool expired;

  bool get isAuthenticated => status == SessionStatus.authenticated;
}

/// Owns the login state. Any authenticated `401` wipes the session (the app
/// then goes back to the login screen, see `CbiApp`).
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    ref.watch(apiClientProvider).onUnauthorized = _onUnauthorized;
    return const SessionState();
  }

  SessionStore get _store => ref.read(sessionStoreProvider);

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
      state = SessionState(
        status: SessionStatus.authenticated,
        user: me,
        credentials: stored.credentials,
      );
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _wipe(expired: true);
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

  Future<void> login({
    required String username,
    required String password,
  }) async {
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
    await _store.setLastUsername(username);
    repo.token = result.token;
    state = SessionState(
      status: SessionStatus.authenticated,
      user: result.user,
      credentials: result.credentials,
    );
  }

  Future<void> logout() async {
    try {
      await ref.read(repositoryProvider).logout();
    } catch (_) {
      // Offline logout still wipes the local session.
    }
    await _wipe();
  }

  /// Updates the password (and user) used for PBIRS NTLM challenges.
  Future<void> updatePbiLogin(PbiCredentials credentials, String password) async {
    await _store.updatePbiLogin(credentials, password);
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

  Future<void> _wipe({bool expired = false}) async {
    ref.read(repositoryProvider).token = null;
    state = SessionState(status: SessionStatus.unauthenticated, expired: expired);
    await _store.clear();
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
