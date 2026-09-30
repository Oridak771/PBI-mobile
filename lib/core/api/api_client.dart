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
/// * calls [onUnauthorized] on any authenticated `401` so the app can wipe the
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

  /// Invoked on `401` for requests made with a token.
  VoidCallback? onUnauthorized;

  Future<ApiResponse> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) => _send('GET', path, query: query, headers: headers);

  Future<ApiResponse> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<ApiResponse> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<ApiResponse> delete(String path) => _send('DELETE', path);

  /// Downloads raw bytes (profile photos). Returns `null` on 404.
  Future<Uint8List?> getBytes(String path) async {
    final uri = config.resolve(path);
    final response = await _guard(
      () => _http.get(uri, headers: _headers(null)).timeout(timeout),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode >= 400) throw _toException(response);
    return response.bodyBytes;
  }

  Future<ApiResponse> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? body,
  }) async {
    if (!config.hasValidBaseUrl) {
      throw const ConfigurationException('API_BASE_URL invalide');
    }
    final uri = config.resolve(path, query);
    final request = http.Request(method, uri)
      ..headers.addAll(_headers(headers));
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    final response = await _guard(() async {
      final streamed = await _http.send(request).timeout(timeout);
      return http.Response.fromStream(streamed).timeout(timeout);
    });
    if (response.statusCode == 304) {
      return ApiResponse(
        statusCode: 304,
        body: null,
        headers: response.headers,
      );
    }
    if (response.statusCode >= 400) throw _toException(response);
    return ApiResponse(
      statusCode: response.statusCode,
      body: _decode(response),
      headers: response.headers,
    );
  }

  Map<String, String> _headers(Map<String, String>? extra) => {
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
    ...?extra,
  };

  ApiException _toException(http.Response response) {
    final decoded = _decode(response);
    final map = decoded is Map ? decoded : const {};
    final exception = ApiException(
      statusCode: response.statusCode,
      code: map['code'] as String?,
      detail: map['detail'] as String?,
      retryAfter: int.tryParse(response.headers['retry-after'] ?? ''),
    );
    if (exception.isUnauthorized && token != null) onUnauthorized?.call();
    return exception;
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
