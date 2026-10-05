import 'dart:convert';
import 'dart:typed_data';

import 'package:cbi_mobile/core/api/api_client.dart';
import 'package:cbi_mobile/core/config/app_config.dart';
import 'package:cbi_mobile/core/errors/app_exception.dart';
import 'package:cbi_mobile/core/storage/catalog_cache_store.dart';
import 'package:cbi_mobile/data/models/ticket.dart';
import 'package:cbi_mobile/data/repositories/api_cbi_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/contract_fixtures.dart';

const config = AppConfig(
  apiBaseUrl: 'http://10.10.10.53:8222',
  demoMode: false,
);

http.Response jsonResponse(
  Object body,
  int status, {
  Map<String, String>? headers,
}) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
);

Map<String, dynamic> ticketJson(int id) => {
  'id': id,
  'title': 'T$id',
  'ticket_type': 'bug',
  'status': 'open',
  'messages_count': 0,
};

void main() {
  group('multipart', () {
    test('request: fields, file part and Bearer header', () async {
      late http.Request seen;
      final client = ApiClient(
        config: config,
        httpClient: MockClient((request) async {
          seen = request;
          return jsonResponse(ticketJson(9), 201);
        }),
      )..token = 'abc';
      final repo = ApiCbiRepository(client);
      final created = await repo.createTicket(
        NewTicket(
          title: 'Accès',
          description: 'Merci',
          ticketType: 'access',
          category: 'bibliotheque',
          priority: 'high',
          attachment: TicketAttachment(
            bytes: Uint8List.fromList([1, 2, 3, 4]),
            filename: 'capture.png',
          ),
        ),
      );
      expect(created.id, 9);
      expect(seen.method, 'POST');
      expect(seen.url.toString(), 'http://10.10.10.53:8222/mobile/v1/tickets/');
      expect(seen.headers['Authorization'], 'Bearer abc');
      expect(
        seen.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      final body = latin1.decode(seen.bodyBytes);
      for (final field in [
        'title',
        'description',
        'ticket_type',
        'category',
        'priority',
      ]) {
        expect(body, contains('name="$field"'));
      }
      expect(body, contains('bibliotheque'));
      expect(body, contains('name="attachment"; filename="capture.png"'));
      expect(seen.bodyBytes.length, greaterThan(4));
    });

    test('builder exposes fields and files', () {
      final request = ApiClient.buildMultipartRequest(
        Uri.parse('http://x/mobile/v1/tickets/1/messages/'),
        fields: {'content': 'Bonjour'},
        files: const [
          MultipartAttachment(
            field: 'attachment',
            bytes: [9, 9],
            filename: 'a.jpg',
          ),
        ],
        headers: {'Authorization': 'Bearer t'},
      );
      expect(request.method, 'POST');
      expect(request.fields, {'content': 'Bonjour'});
      expect(request.files.single.field, 'attachment');
      expect(request.files.single.filename, 'a.jpg');
      expect(request.files.single.length, 2);
      expect(request.headers['Authorization'], 'Bearer t');
    });

    test('message without image has no file part', () async {
      late http.Request seen;
      final repo = ApiCbiRepository(
        ApiClient(
          config: config,
          httpClient: MockClient((request) async {
            seen = request;
            return jsonResponse({
              'id': 3,
              'content': 'Salut',
              'is_mine': true,
            }, 201);
          }),
        )..token = 'abc',
      );
      final message = await repo.sendTicketMessage(1, 'Salut');
      expect(message.content, 'Salut');
      expect(seen.url.path, '/mobile/v1/tickets/1/messages/');
      final body = latin1.decode(seen.bodyBytes);
      expect(body, contains('name="content"'));
      expect(body, isNot(contains('filename=')));
    });

    test('401 renews the token and resends the whole multipart body', () async {
      final auth = <String?>[];
      final bodies = <int>[];
      final client = ApiClient(
        config: config,
        httpClient: MockClient((request) async {
          auth.add(request.headers['Authorization']);
          bodies.add(request.bodyBytes.length);
          return request.headers['Authorization'] == 'Bearer old'
              ? jsonResponse({
                  'detail': 'Session expirée.',
                  'code': 'session_expired',
                }, 401)
              : jsonResponse(ticketJson(1), 201);
        }),
      )..token = 'old';
      client.reauthenticate = () async {
        client.token = 'new';
        return true;
      };
      await ApiCbiRepository(client).createTicket(
        NewTicket(
          title: 't',
          description: 'd',
          attachment: TicketAttachment(
            bytes: Uint8List(100),
            filename: 'a.jpg',
          ),
        ),
      );
      expect(auth, ['Bearer old', 'Bearer new']);
      expect(bodies[0], bodies[1]);
    });

    test('400 form errors are exposed field by field', () async {
      final repo = ApiCbiRepository(
        ApiClient(
          config: config,
          httpClient: MockClient(
            (_) async => jsonResponse({
              'detail': 'Ce champ est obligatoire.',
              'code': 'bad_request',
              'errors': {
                'title': ['Ce champ est obligatoire.'],
                'attachment': ["L'image ne doit pas dépasser 5 Mo."],
              },
            }, 400),
          ),
        )..token = 'abc',
      );
      await expectLater(
        repo.createTicket(const NewTicket(title: '', description: 'd')),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 400)
              .having(
                (e) => e.fieldErrors['title'],
                'title',
                'Ce champ est obligatoire.',
              )
              .having((e) => e.fieldErrors.keys, 'fields', [
                'title',
                'attachment',
              ]),
        ),
      );
    });
  });

  test('list query, choices, admins and admin update', () async {
    final requests = <http.Request>[];
    final repo = ApiCbiRepository(
      ApiClient(
        config: config,
        httpClient: MockClient((request) async {
          requests.add(request);
          return switch (request.url.path) {
            '/mobile/v1/tickets/' => jsonResponse({
              'is_admin': true,
              'tickets': [ticketJson(1)],
            }, 200),
            '/mobile/v1/tickets/choices/' => jsonResponse({
              'is_admin': true,
              'max_attachment_bytes': 100,
            }, 200),
            '/mobile/v1/tickets/admins/' => jsonResponse({
              'admins': [
                {'id': 7, 'name': 'Cellule BI', 'initials': 'CB'},
              ],
            }, 200),
            _ => jsonResponse(ticketJson(1)..['status'] = 'closed', 200),
          };
        }),
      )..token = 'abc',
    );
    final list = await repo.fetchTickets(
      filter: const TicketFilter(status: 'open', assignedToMe: true),
    );
    expect(list.isAdmin, isTrue);
    expect(requests.last.url.queryParameters, {
      'status': 'open',
      'assigned': 'me',
    });
    await repo.fetchTickets();
    expect(requests.last.url.query, isEmpty);

    final choices = await repo.fetchTicketChoices();
    expect(choices.maxAttachmentBytes, 100);
    expect(choices.ticketTypes, isNotEmpty, reason: 'defaults kept');
    expect((await repo.fetchTicketAdmins()).single.name, 'Cellule BI');

    final updated = await repo.updateTicket(
      1,
      const TicketUpdate.assignee(null),
    );
    expect(updated.status, 'closed');
    expect(requests.last.url.path, '/mobile/v1/tickets/1/update/');
    expect(requests.last.method, 'POST');
    expect(jsonDecode(requests.last.body), {'assigned_to': null});
  });

  group('catalog cache', () {
    test(
      'saved after a fetch, served at launch, revalidated with its ETag',
      () async {
        final cache = MemoryCatalogCacheStore();
        final etags = <String?>[];
        ApiCbiRepository repo() => ApiCbiRepository(
          ApiClient(
            config: config,
            httpClient: MockClient((request) async {
              etags.add(request.headers['If-None-Match']);
              if (request.headers['If-None-Match'] == '"v1"') {
                return http.Response('', 304, headers: {'etag': '"v1"'});
              }
              return jsonResponse(
                contractCatalog(),
                200,
                headers: {'etag': '"v1"'},
              );
            }),
          )..token = 'abc',
          cache: cache,
        );

        final first = repo();
        expect(await first.cachedCatalog(), isNull);
        final fetched = await first.fetchCatalog();
        expect(cache.entry?.etag, '"v1"');

        // "Next launch": a new repository reads the saved copy first.
        final second = repo();
        final cached = await second.cachedCatalog();
        expect(cached?.sections.length, fetched.sections.length);
        final refreshed = await second.fetchCatalog();
        expect(etags, [null, '"v1"']);
        expect(refreshed.sections.length, fetched.sections.length);

        await second.clearCatalogCache();
        expect(cache.entry, isNull);
        expect(await repo().cachedCatalog(), isNull);
      },
    );
  });
}
