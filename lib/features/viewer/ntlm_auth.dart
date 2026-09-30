/// NTLM / HTTP-auth policy of the report viewer (pure logic, unit tested).
library;

enum HttpAuthDecision {
  /// Answer with the stored `DOMAIN\username` + password.
  useStoredCredentials,

  /// Ask the user (wrong/expired password, or none stored).
  askUser,

  /// Unknown host: never send credentials.
  cancel,
}

String _normalizeHost(String host) {
  var h = host.trim().toLowerCase();
  if (h.endsWith('.')) h = h.substring(0, h.length - 1);
  // Strip a port ("10.20.10.63:80"); IPv6 literals keep their brackets.
  final colon = h.lastIndexOf(':');
  if (colon > 0 && !h.startsWith('[') && h.indexOf(':') == colon) {
    h = h.substring(0, colon);
  }
  return h;
}

/// `true` when [host] is one of the PBIRS hosts (`catalog.servers[].host`),
/// compared case-insensitively.
bool isAllowedPbiHost(String host, Iterable<String> allowedHosts) {
  final h = _normalizeHost(host);
  if (h.isEmpty) return false;
  return allowedHosts.any((a) => _normalizeHost(a) == h);
}

/// Decides how to answer an HTTP auth challenge.
///
/// [previousAttempts] counts the challenges already answered for this host
/// during the current view: the first one uses the stored password, any
/// further one means the password was rejected and the user is asked.
HttpAuthDecision decideHttpAuth({
  required String host,
  required Iterable<String> allowedHosts,
  required int previousAttempts,
  required bool hasStoredPassword,
}) {
  if (!isAllowedPbiHost(host, allowedHosts)) return HttpAuthDecision.cancel;
  if (previousAttempts == 0 && hasStoredPassword) {
    return HttpAuthDecision.useStoredCredentials;
  }
  return HttpAuthDecision.askUser;
}

/// Per-view challenge counter.
class NtlmChallengeTracker {
  NtlmChallengeTracker(Iterable<String> allowedHosts)
    : allowedHosts = allowedHosts.toSet();

  final Set<String> allowedHosts;
  final Map<String, int> _attempts = {};

  HttpAuthDecision next(String host, {required bool hasStoredPassword}) {
    final key = _normalizeHost(host);
    final decision = decideHttpAuth(
      host: host,
      allowedHosts: allowedHosts,
      previousAttempts: _attempts[key] ?? 0,
      hasStoredPassword: hasStoredPassword,
    );
    if (decision != HttpAuthDecision.cancel) {
      _attempts[key] = (_attempts[key] ?? 0) + 1;
    }
    return decision;
  }

  /// Forget the attempts (manual refresh).
  void reset() => _attempts.clear();
}
