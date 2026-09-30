import 'dart:convert';
import 'dart:io';

import 'package:cbi_mobile/core/api/api_client.dart';
import 'package:cbi_mobile/core/config/app_config.dart';
import 'package:cbi_mobile/core/errors/app_exception.dart';
import 'package:cbi_mobile/data/repositories/api_cbi_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/contract_fixtures.dart';

const config = AppConfig(apiBaseUrl: 'http://10.10.10.53:8222', demoMode: false);

http.Response jsonResponse(Object body, int status, {Map<String, String>? headers}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
    );

void main() {
  group('ApiClient', () {
    test('sends Bearer token to /mobile/v1/ and decodes JSON', () async {
      late http.Request seen;
      final client = ApiClient(
        config: config,
        httpClient: MockClient((request) async {
          seen = request;
          return jsonResponse({'unread_count': 3, 'latest_id': 8}, 200);
        }),
      )..token = 'abc';
      final response = await client.get('notifications/unread-count/');
      expect(seen.url.toString(),
          'http://10.10.10.53:8222/mobile/v1/notifications/unread-count/');
      expect(seen.headers['Authorization'], 'Bearer abc');
      expect(response.json['unread_count'], 3);
    });

    test('maps {"detail","code"} errors and signals 401 globally', () async {
      var unauthorized = 0;
      final client = ApiClient(
        config: config,
        httpClient: MockClient(
          (_) async => jsonResponse({
            'detail': 'Session expirée.',
            'code': 'session_expired',
          }, 401),
        ),
      )
        ..token = 'abc'
        ..onUnauthorized = () => unauthorized++;
      await expectLater(
        client.get('me/'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 401)
              .having((e) => e.code, 'code', 'session_expired'),
        ),
      );
      expect(unauthorized, 1);
    });

    test('401 on login (no token) is not a session expiry', () async {
      var unauthorized = 0;
      final client = ApiClient(
        config: config,
        httpClient: MockClient(
          (_) async => jsonResponse({
            'detail': 'Identifiants invalides.',
            'code': 'invalid_credentials',
          }, 401),
        ),
      )..onUnauthorized = () => unauthorized++;
      await expectLater(client.post('auth/login/', body: {}), throwsA(isA<ApiException>()));
      expect(unauthorized, 0);
    });

    test('transport failures become NetworkException', () async {
      final client = ApiClient(
        config: config,
        httpClient: MockClient((_) async => throw const SocketException('down')),
      );
      await expectLater(client.get('config/'), throwsA(isA<NetworkException>()));
    });

    test('invalid base URL is rejected before any request', () async {
      final client = ApiClient(
        config: const AppConfig(apiBaseUrl: 'http://example.com', demoMode: false),
        httpClient: MockClient((_) async => fail('must not be called')),
      );
      await expectLater(client.get('config/'), throwsA(isA<ConfigurationException>()));
    });
  });

  test('catalog uses If-None-Match and serves the cache on 304', () async {
    final requests = <http.Request>[];
    final repo = ApiCbiRepository(
      ApiClient(
        config: config,
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.headers['If-None-Match'] == '"v1"') {
            return http.Response('', 304);
          }
          return jsonResponse(contractCatalog(), 200, headers: {'etag': '"v1"'});
        }),
      ),
    )..token = 't';
    final first = await repo.fetchCatalog();
    final second = await repo.fetchCatalog();
    expect(requests, hasLength(2));
    expect(requests.first.headers.containsKey('If-None-Match'), isFalse);
    expect(requests.last.headers['If-None-Match'], '"v1"');
    expect(identical(first, second), isTrue);
    expect(second.sections, isNotEmpty);
  });

  group('errorMessage (French)', () {
    test('uses the server detail when present', () {
      expect(
        errorMessage(const ApiException(statusCode: 403, code: 'forbidden', detail: 'Accès interdit.')),
        'Accès interdit.',
      );
    });

    test('maps codes and statuses', () {
      expect(errorMessage(const NetworkException()), ErrorMessages.network);
      expect(errorMessage(const ApiException(statusCode: 500)), ErrorMessages.server);
      expect(
        errorMessage(const ApiException(statusCode: 503, code: 'directory_unavailable')),
        ErrorMessages.server,
      );
      expect(errorMessage(const ApiException(statusCode: 401)), ErrorMessages.sessionExpired);
      expect(errorMessage(const ApiException(statusCode: 404)), ErrorMessages.notFound);
      expect(
        errorMessage(const ApiException(statusCode: 429, code: 'throttled', retryAfter: 30)),
        contains('30'),
      );
    });

    test('login messages follow the legacy app', () {
      final invalid = loginErrorMessage(
        const ApiException(statusCode: 401, code: 'invalid_credentials'),
      );
      expect(invalid.message, 'Email ou mot de passe invalide');
      expect(invalid.onPasswordField, isTrue);
      expect(
        loginErrorMessage(const ApiException(statusCode: 401, code: 'identifier_unknown')).message,
        'Email ou mot de passe invalide',
      );
      expect(
        loginErrorMessage(const ApiException(statusCode: 403, code: 'account_inactive')).message,
        'Accès refusé.\nVeuillez contacter Helpdesk BI',
      );
      expect(
        loginErrorMessage(const NetworkException()).message,
        'Vérifiez votre connexion internet',
      );
      expect(
        loginErrorMessage(const ApiException(statusCode: 503, code: 'directory_unavailable')).message,
        'Connexion impossible.\nVeuillez contacter Helpdesk BI',
      );
    });
  });
}
