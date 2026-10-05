import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../errors/app_exception.dart';

/// Decoded API response.
class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
  });

  final int statusCode;

  /// Decoded JSON body (`null` for empty bodies / 304).
  final Object? body;
  final Map<String, String> headers;

  bool get isNotModified => statusCode == 304;

  Map<String, dynamic> get json =>
      body is Map<String, dynamic> ? body as Map<String, dynamic> : const {};
}

/// Thin HTTP client for `<API_BASE_URL>/mobile/v1/`.
///
/// * adds `Authorization: Bearer <token>` when a token is set,
/// * maps transport failures to [NetworkException],
/// * maps `{"detail","code"}` errors to [ApiException],
/// * on an authenticated `401`, asks [reauthenticate] for a new token (one
///   attempt shared by all concurrent requests) and retries the request once,
/// * calls [onUnauthorized] when the `401` stands, so the app can wipe the
///   session and go back to the login screen.
class ApiClient {
  ApiClient({
    required this.config,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? http.Client();

  final AppConfig config;
  final http.Client _http;
  final Duration timeout;

  /// Current session token (set by the session controller).
  String? token;

  /// Invoked on `401` for requests made with a token (after a failed
  /// [reauthenticate]).
  VoidCallback? onUnauthorized;

  /// Silent re-login: sets a fresh [token] and returns `true`, or returns
  /// `false`. Called at most once at a time.
  Future<bool> Function()? reauthenticate;

  Future<bool>? _reauthInFlight;

  Future<ApiResponse> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) => _send('GET', path, query: query, headers: headers);

  /// [authenticated] `false`: no Bearer header, no re-login, no session
  /// expiry on `401` (login). [renewOn401] `false`: a `401` is not retried
  /// with a new token (logout).
  Future<ApiResponse> post(
    String path, {
    Object? body,
    bool authenticated = true,
    bool renewOn401 = true,
  }) => _send(
    'POST',
    path,
    body: body,
    authenticated: authenticated,
    renewOn401: renewOn401,
  );

  Future<ApiResponse> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<ApiResponse> delete(String path) => _send('DELETE', path);

  /// Downloads raw bytes (profile photos). Returns `null` on 404.
  Future<Uint8List?> getBytes(String path) async {
    final uri = config.resolve(path);
    final response = await _run(
      (bearer) => _http.get(uri, headers: _headers(null, bearer)).timeout(timeout),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode >= 400) throw _toException(response);
    return response.bodyBytes;
  }

  /// `POST` as `multipart/form-data`: text [fields] plus [files] (ticket
  /// attachments). Same Bearer / `401` re-login / error handling as [post];
  /// the request is rebuilt from the in-memory bytes for the retry.
  Future<ApiResponse> postMultipart(
    String path, {
    Map<String, String> fields = const {},
    List<MultipartAttachment> files = const [],
  }) async {
    final uri = _uri(path);
    return _sendBuilt(
      (bearer) => buildMultipartRequest(
        uri,
        fields: fields,
        files: files,
        headers: _headers(null, bearer),
      ),
    );
  }

  /// The `multipart/form-data` request sent by [postMultipart].
  static http.MultipartRequest buildMultipartRequest(
    Uri uri, {
    Map<String, String> fields = const {},
    List<MultipartAttachment> files = const [],
    Map<String, String> headers = const {},
  }) => http.MultipartRequest('POST', uri)
    ..headers.addAll(headers)
    ..fields.addAll(fields)
    ..files.addAll([
      for (final f in files)
        http.MultipartFile.fromBytes(f.field, f.bytes, filename: f.filename),
    ]);

  Uri _uri(String path, [Map<String, String>? query]) {
    if (!config.hasValidBaseUrl) {
      throw const ConfigurationException('API_BASE_URL invalide');
    }
    return config.resolve(path, query);
  }

  Future<ApiResponse> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? body,
    bool authenticated = true,
    bool renewOn401 = true,
  }) async {
    final uri = _uri(path, query);
    return _sendBuilt(
      (bearer) {
        final request = http.Request(method, uri)
          ..headers.addAll(_headers(headers, bearer));
        if (body != null) {
          request.headers['Content-Type'] = 'application/json; charset=utf-8';
          request.body = jsonEncode(body);
        }
        return request;
      },
      authenticated: authenticated,
      renewOn401: renewOn401,
    );
  }

  /// Sends the request made by [build] (called again for the retry: a
  /// request can only be sent once) and decodes the answer.
  Future<ApiResponse> _sendBuilt(
    http.BaseRequest Function(String? bearer) build, {
    bool authenticated = true,
    bool renewOn401 = true,
  }) async {
    final response = await _run(
      (bearer) async {
        final streamed = await _http.send(build(bearer)).timeout(timeout);
        return http.Response.fromStream(streamed).timeout(timeout);
      },
      authenticated: authenticated,
      renewOn401: renewOn401,
    );
    if (response.statusCode == 304) {
      return ApiResponse(
        statusCode: 304,
        body: null,
        headers: response.headers,
      );
    }
    if (response.statusCode >= 400) {
      throw _toException(response, notify: authenticated);
    }
    return ApiResponse(
      statusCode: response.statusCode,
      body: _decode(response),
      headers: response.headers,
    );
  }

  /// Sends with the current token; on `401` renews it once and retries.
  Future<http.Response> _run(
    Future<http.Response> Function(String? bearer) send, {
    bool authenticated = true,
    bool renewOn401 = true,
  }) async {
    final sent = authenticated ? token : null;
    final response = await _guard(() => send(sent));
    if (response.statusCode != 401 || sent == null || !renewOn401) {
      return response;
    }
    if (!await _renew(sent)) return response;
    return _guard(() => send(token));
  }

  /// `true` when a token different from [rejected] is now available.
  Future<bool> _renew(String rejected) async {
    // Another request already renewed the token (or the session ended).
    if (token != rejected) return token != null;
    final hook = reauthenticate;
    if (hook == null) return false;
    final attempt = _reauthInFlight ??= _attempt(hook);
    final ok = await attempt;
    if (identical(_reauthInFlight, attempt)) _reauthInFlight = null;
    return ok && token != null && token != rejected;
  }

  static Future<bool> _attempt(Future<bool> Function() hook) async {
    try {
      return await hook();
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _headers(Map<String, String>? extra, String? bearer) => {
    'Accept': 'application/json',
    if (bearer != null) 'Authorization': 'Bearer $bearer',
    ...?extra,
  };

  ApiException _toException(http.Response response, {bool notify = true}) {
    final decoded = _decode(response);
    final map = decoded is Map ? decoded : const {};
    final exception = ApiException(
      statusCode: response.statusCode,
      code: map['code'] as String?,
      detail: map['detail'] as String?,
      retryAfter: int.tryParse(response.headers['retry-after'] ?? ''),
      errors: _fieldErrors(map['errors']),
    );
    if (notify && exception.isUnauthorized && token != null) {
      onUnauthorized?.call();
    }
    return exception;
  }

  static Map<String, List<String>> _fieldErrors(Object? errors) {
    if (errors is! Map) return const {};
    return {
      for (final e in errors.entries)
        '${e.key}': e.value is List
            ? [for (final m in e.value as List) '$m']
            : ['${e.value}'],
    };
  }

  static Object? _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  static Future<http.Response> _guard(
    Future<http.Response> Function() run,
  ) async {
    try {
      return await run();
    } on SocketException catch (e) {
      throw NetworkException(e);
    } on TimeoutException catch (e) {
      throw NetworkException(e);
    } on HandshakeException catch (e) {
      throw NetworkException(e);
    } on http.ClientException catch (e) {
      throw NetworkException(e);
    }
  }

  void close() => _http.close();
}

/// File part of [ApiClient.postMultipart].
class MultipartAttachment {
  const MultipartAttachment({
    required this.field,
    required this.bytes,
    required this.filename,
  });

  final String field;
  final List<int> bytes;
  final String filename;
}
