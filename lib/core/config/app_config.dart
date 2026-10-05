/// Compile-time configuration, driven by `--dart-define`.
///
/// * `API_BASE_URL` – origin of the CBI Django platform
///   (default `http://10.10.10.53:8222`). The mobile API lives under
///   `<API_BASE_URL>/mobile/v1/`.
/// * `ENABLE_DEMO_MODE` – when `true` the app runs on fixture data
///   (no network), see `DemoCbiRepository`.
class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.demoMode});

  static const defaultApiBaseUrl = 'http://10.10.10.53:8222';

  /// Reads the values injected with `--dart-define`.
  factory AppConfig.fromEnvironment() => AppConfig(
    apiBaseUrl: normalizeBaseUrl(
      const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: defaultApiBaseUrl,
      ),
    ),
    demoMode: const bool.fromEnvironment('ENABLE_DEMO_MODE'),
  );

  final String apiBaseUrl;
  final bool demoMode;

  /// `<API_BASE_URL>/mobile/v1/`.
  Uri get apiV1 => Uri.parse('$apiBaseUrl/mobile/v1/');

  bool get hasValidBaseUrl => isValidApiBaseUrl(apiBaseUrl);

  /// Absolute URL for a path relative to `mobile/v1/` or an absolute server
  /// path such as `/mobile/v1/me/photo/` (a query string in [path] is kept,
  /// e.g. the versioned `/mobile/v1/metadata/9/logo/?v=…`).
  Uri resolve(String path, [Map<String, String>? query]) {
    final uri = path.startsWith('/')
        ? Uri.parse(apiBaseUrl).resolve(path)
        : apiV1.resolve(path);
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  /// `true` when [uri] points at the CBI platform itself (same scheme, host
  /// and port as `API_BASE_URL`): only then may the Bearer token be sent.
  bool isApiOrigin(Uri uri) {
    final base = Uri.tryParse(apiBaseUrl);
    if (base == null) return false;
    return uri.scheme == base.scheme &&
        uri.host.toLowerCase() == base.host.toLowerCase() &&
        uri.port == base.port;
  }

  static String normalizeBaseUrl(String value) {
    var v = value.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }
}

/// Validates the API origin.
///
/// Accepted: `https://<any host>[:port]` or `http://` on a private-network /
/// loopback address (the CBI platform runs on the internal network). Paths,
/// query strings, fragments and embedded credentials are rejected.
bool isValidApiBaseUrl(String value) {
  final input = value.trim();
  if (input.isEmpty) return false;
  final uri = Uri.tryParse(input);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return false;
  if (uri.userInfo.isNotEmpty) return false;
  if (!(uri.path.isEmpty || uri.path == '/')) return false;
  if (uri.hasQuery || uri.hasFragment) return false;
  if (uri.scheme == 'https') return true;
  if (uri.scheme == 'http') return isPrivateNetworkHost(uri.host);
  return false;
}

/// `true` for loopback, RFC 1918 IPv4 addresses and `localhost`.
bool isPrivateNetworkHost(String host) {
  final h = host.toLowerCase();
  if (h == 'localhost') return true;
  final parts = h.split('.');
  if (parts.length != 4) return false;
  final octets = parts.map(int.tryParse).toList();
  if (octets.any((o) => o == null || o < 0 || o > 255)) return false;
  final a = octets[0]!, b = octets[1]!;
  return a == 10 ||
      a == 127 ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 168);
}
