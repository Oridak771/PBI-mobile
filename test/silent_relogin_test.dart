import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cbi_mobile/core/api/api_client.dart';
import 'package:cbi_mobile/core/config/app_config.dart';
import 'package:cbi_mobile/core/errors/app_exception.dart';
import 'package:cbi_mobile/core/providers.dart';
import 'package:cbi_mobile/core/security/biometric_auth.dart';
import 'package:cbi_mobile/core/storage/lock_settings_store.dart';
import 'package:cbi_mobile/core/storage/remembered_credentials_store.dart';
import 'package:cbi_mobile/core/storage/session_store.dart';
import 'package:cbi_mobile/core/theme/app_theme.dart';
import 'package:cbi_mobile/data/models/user.dart';
import 'package:cbi_mobile/features/auth/login_screen.dart';
import 'package:cbi_mobile/features/auth/session_controller.dart';
import 'package:cbi_mobile/features/lock/app_lock_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/test_app.dart';

const _config = AppConfig(apiBaseUrl: 'http://10.10.10.53:8222', demoMode: false);

const _user = {
  'id': 7,
  'username': 'H0017549',
  'name': 'Mohammed Bouhariz',
  'initials': 'MB',
};

http.Response _json(Object body, int status) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Fake CBI server: accepts [validTokens]; `auth/login/` answers [login].
class FakeServer {
  FakeServer({required this.validTokens});

  final Set<String> validTokens;
  http.Response Function(Map<String, dynamic> body) login = (_) => _json({
    'token': 'fresh',
    'user': _user,
    'credentials': {'domain': 'GSH', 'username': 'H0017549'},
  }, 200);
  final loginBodies = <Map<String, dynamic>>[];
  final loginAuthHeaders = <String?>[];
  final seen = <String>[];

  /// Delays `auth/login/` until completed (concurrency tests).
  Completer<void>? loginGate;

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    seen.add('${request.method} $path ${request.headers['Authorization']}');
    if (path.endsWith('/auth/login/')) {
      loginBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      loginAuthHeaders.add(request.headers['Authorization']);
      await loginGate?.future;
      final response = login(loginBodies.last);
      if (response.statusCode == 200) validTokens.add('fresh');
      return response;
    }
    final bearer = request.headers['Authorization']?.replaceFirst('Bearer ', '');
    if (bearer == null || !validTokens.contains(bearer)) {
      return _json({'detail': 'Session expirée.', 'code': 'session_expired'}, 401);
    }
    if (path.endsWith('/me/')) return _json(_user, 200);
    if (path.endsWith('/notifications/unread-count/')) {
      return _json({'unread_count': 2, 'latest_id': 9}, 200);
    }
    return _json({}, 200);
  }
}

class Harness {
  Harness({
    required this.server,
    RememberedCredentials? remembered,
    LockSettings lock = const LockSettings(),
    bool withSession = true,
  }) : remembered = MemoryRememberedCredentialsStore(remembered),
       lockStore = MemoryLockSettingsStore(lock),
       store = MemorySessionStore(
         session: withSession
             ? const StoredSession(
                 token: 'expired',
                 user: User(id: 7, username: 'H0017549', name: 'Mohammed Bouhariz'),
                 credentials: PbiCredentials(domain: 'GSH', username: 'H0017549'),
                 password: 'old-ntlm',
               )
             : null,
       ) {
    client = ApiClient(config: _config, httpClient: MockClient(server.handle));
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(_config),
        apiClientProvider.overrideWithValue(client),
        sessionStoreProvider.overrideWithValue(store),
        rememberedCredentialsStoreProvider.overrideWithValue(this.remembered),
        lockSettingsStoreProvider.overrideWithValue(lockStore),
        biometricAuthProvider.overrideWithValue(biometrics),
        appVersionProvider.overrideWith((ref) => '3.2.0'),
      ],
    );
    // Installs the client hooks.
    container.read(sessionProvider);
  }

  final FakeServer server;
  final MemoryRememberedCredentialsStore remembered;
  final MemoryLockSettingsStore lockStore;
  final MemorySessionStore store;
  final biometrics = FakeBiometricAuth();
  late final ApiClient client;
  late final ProviderContainer container;

  SessionController get session => container.read(sessionProvider.notifier);
  SessionState get state => container.read(sessionProvider);

  void dispose() => container.dispose();
}

void main() {
  const saved = RememberedCredentials(username: 'H0017549', password: 'secret');

  test('splash: rejected token → one silent login, request retried', () async {
    final server = FakeServer(validTokens: {});
    final h = Harness(server: server, remembered: saved);
    addTearDown(h.dispose);

    expect(await h.session.restore(), isTrue);

    expect(server.loginBodies, hasLength(1));
    expect(server.loginBodies.single['username'], 'H0017549');
    expect(server.loginBodies.single['password'], 'secret');
    expect(server.loginBodies.single['app_version'], '3.2.0');
    // Never sent with the expired token.
    expect(server.loginAuthHeaders.single, isNull);
    expect(h.state.isAuthenticated, isTrue);
    expect(h.client.token, 'fresh');
    expect((await h.store.read())?.token, 'fresh');
    // me/ sent twice: expired token, then the fresh one.
    expect(server.seen.where((s) => s.contains('/me/')), [
      'GET /mobile/v1/me/ Bearer expired',
      'GET /mobile/v1/me/ Bearer fresh',
    ]);
  });

  test('concurrent 401s share a single re-login attempt', () async {
    final server = FakeServer(validTokens: {})..loginGate = Completer<void>();
    final h = Harness(server: server, remembered: saved);
    addTearDown(h.dispose);
    final repo = h.container.read(repositoryProvider)..token = 'expired';
    // All three get a 401 while the (gated) login is in flight.
    final pending = Future.wait([
      repo.fetchUnreadCount(),
      repo.fetchMe(),
      repo.fetchUnreadCount(),
    ]);
    await pumpEventQueue();
    server.loginGate!.complete();
    final results = await pending;

    expect(server.loginBodies, hasLength(1));
    expect(results, hasLength(3));
    expect(h.client.token, 'fresh');
  });

  test('retry still 401 → session wiped once, no loop', () async {
    final server = FakeServer(validTokens: {});
    // The fresh token is refused too.
    server.login = (_) => _json({
      'token': 'also-refused',
      'user': _user,
      'credentials': {'domain': 'GSH', 'username': 'H0017549'},
    }, 200);
    final h = Harness(server: server, remembered: saved);
    addTearDown(h.dispose);

    expect(await h.session.restore(), isFalse);
    expect(server.loginBodies, hasLength(1));
    expect(h.state.status, SessionStatus.unauthenticated);
    expect(h.state.expired, isTrue);
    expect(h.state.passwordChanged, isFalse);
    // Remembered credentials untouched.
    expect((await h.remembered.read())?.password, 'secret');
  });

  test('invalid_credentials → password dropped, username kept, message', () async {
    final server = FakeServer(validTokens: {});
    server.login = (_) => _json({
      'detail': 'Identifiants invalides.',
      'code': 'invalid_credentials',
    }, 401);
    final h = Harness(server: server, remembered: saved);
    addTearDown(h.dispose);

    expect(await h.session.restore(), isFalse);
    expect(server.loginBodies, hasLength(1));
    expect(h.state.status, SessionStatus.unauthenticated);
    expect(h.state.passwordChanged, isTrue);
    expect(await h.store.read(), isNull);
    final left = await h.remembered.read();
    expect(left?.username, 'H0017549');
    expect(left?.password, isNull);
  });

  for (final (label, failure) in [
    ('network', () => throw const SocketException('down')),
    ('429', () => _json({'detail': 'Trop de tentatives.', 'code': 'throttled'}, 429)),
  ]) {
    test('$label failure during re-login → normal expiry, nothing deleted', () async {
      final server = FakeServer(validTokens: {});
      server.login = (_) => failure();
      final h = Harness(server: server, remembered: saved);
      addTearDown(h.dispose);

      expect(await h.session.restore(), isFalse);
      expect(server.loginBodies, hasLength(1));
      expect(h.state.status, SessionStatus.unauthenticated);
      expect(h.state.expired, isTrue);
      expect(h.state.passwordChanged, isFalse);
      expect(await h.remembered.read(), isNotNull);
      expect((await h.remembered.read())?.password, 'secret');
    });
  }

  test('without remembered credentials a 401 simply ends the session', () async {
    final server = FakeServer(validTokens: {});
    final h = Harness(server: server);
    addTearDown(h.dispose);
    expect(await h.session.restore(), isFalse);
    expect(server.loginBodies, isEmpty);
    expect(h.state.expired, isTrue);
  });

  test('401 while authenticated: re-login refreshes the session state', () async {
    final server = FakeServer(validTokens: {'expired'});
    final h = Harness(server: server, remembered: saved);
    addTearDown(h.dispose);
    expect(await h.session.restore(), isTrue);
    expect(server.loginBodies, isEmpty);

    server.validTokens.remove('expired'); // revoked server-side
    final count = await h.container.read(repositoryProvider).fetchUnreadCount();
    expect(count.unreadCount, 2);
    expect(server.loginBodies, hasLength(1));
    expect(h.state.isAuthenticated, isTrue);
    expect(h.state.user?.name, 'Mohammed Bouhariz');
  });

  test('locked app: the re-login waits for the unlock', () async {
    final server = FakeServer(validTokens: {'expired'});
    final h = Harness(
      server: server,
      remembered: saved,
      lock: const LockSettings(enabled: true),
    );
    addTearDown(h.dispose);
    expect(await h.session.restore(), isTrue);
    final lock = h.container.read(appLockProvider.notifier);
    await lock.load();
    expect(lock.lockOnColdStart(hasSession: true), isTrue);

    server.validTokens.remove('expired');
    var done = false;
    final pending = h.container
        .read(repositoryProvider)
        .fetchUnreadCount()
        .whenComplete(() => done = true);
    await pumpEventQueue();
    expect(server.loginBodies, isEmpty, reason: 'no login behind the lock');
    expect(done, isFalse);

    expect(await lock.unlock(), isTrue);
    await pending;
    expect(server.loginBodies, hasLength(1));
  });

  test('logout keeps the remembered credentials and the lock setting', () async {
    final server = FakeServer(validTokens: {'expired'});
    final h = Harness(
      server: server,
      remembered: saved,
      lock: const LockSettings(enabled: true, delay: LockDelay.fiveMinutes),
    );
    addTearDown(h.dispose);
    expect(await h.session.restore(), isTrue);
    await h.session.logout();
    expect(h.state.status, SessionStatus.unauthenticated);
    expect(await h.store.read(), isNull);
    expect((await h.remembered.read())?.password, 'secret');
    expect(h.lockStore.settings.enabled, isTrue);
    expect(h.lockStore.settings.delay, LockDelay.fiveMinutes);
    // Logout is never "renewed" with a silent login.
    expect(server.loginBodies, isEmpty);
  });

  test('NTLM prompt keeps the remembered password in sync', () async {
    final server = FakeServer(validTokens: {'expired'});
    final h = Harness(server: server, remembered: saved);
    addTearDown(h.dispose);
    expect(await h.session.restore(), isTrue);
    await h.session.updatePbiLogin(
      const PbiCredentials(domain: 'GSH', username: 'H0017549'),
      'new-ad-password',
    );
    expect((await h.remembered.read())?.password, 'new-ad-password');
    expect((await h.store.read())?.password, 'new-ad-password');
  });

  test('login: "Se souvenir de moi" off forgets, on saves', () async {
    final server = FakeServer(validTokens: {});
    final h = Harness(server: server, remembered: saved, withSession: false);
    addTearDown(h.dispose);

    await h.session.login(username: 'other', password: 'pw', remember: false);
    expect(await h.remembered.read(), isNull);
    await h.session.logout();

    await h.session.login(username: 'H0017549', password: 'pw2');
    final kept = await h.remembered.read();
    expect(kept?.username, 'H0017549');
    expect(kept?.password, 'pw2');
  });

  testWidgets('login screen after a password change: message, username only', (
    tester,
  ) async {
    final server = FakeServer(validTokens: {});
    server.login = (_) => _json({'code': 'invalid_credentials'}, 401);
    final h = Harness(server: server, remembered: saved);
    addTearDown(h.dispose);
    await tester.runAsync(() => h.session.restore());
    expect(h.state.passwordChanged, isTrue);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(theme: buildLightTheme(), home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(ErrorMessages.passwordChanged), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.first.controller!.text, 'H0017549');
    expect(fields.last.controller!.text, isEmpty);
    expect(find.byKey(const Key('login-biometric')), findsNothing);
  });
}
