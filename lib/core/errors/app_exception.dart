/// Error returned by the CBI API: `{"detail": "<fr>", "code": "<machine>"}`.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    this.code,
    this.detail,
    this.retryAfter,
    this.errors = const {},
  });

  final int statusCode;
  final String? code;
  final String? detail;

  /// Form validation errors of a `400` (`{"errors": {field: [messages]}}`).
  final Map<String, List<String>> errors;

  /// First message of each field of [errors].
  Map<String, String> get fieldErrors => {
    for (final e in errors.entries)
      if (e.value.isNotEmpty) e.key: e.value.first,
  };

  /// Seconds, from the `Retry-After` header on `429`.
  final int? retryAfter;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'ApiException($statusCode, $code, $detail)';
}

/// The server could not be reached (offline, timeout, DNS, TLS...).
class NetworkException implements Exception {
  const NetworkException([this.cause]);
  final Object? cause;

  @override
  String toString() => 'NetworkException($cause)';
}

/// Invalid `API_BASE_URL` configuration.
class ConfigurationException implements Exception {
  const ConfigurationException(this.message);
  final String message;

  @override
  String toString() => 'ConfigurationException($message)';
}

/// Legacy French messages.
abstract final class ErrorMessages {
  static const network = 'Vérifiez votre connexion internet';
  static const server = 'Connexion impossible.\nVeuillez contacter Helpdesk BI';
  static const inactive = 'Accès refusé.\nVeuillez contacter Helpdesk BI';
  static const invalidCredentials = 'Email ou mot de passe invalide';
  static const sessionExpired =
      'Votre session a expiré. Veuillez vous reconnecter.';
  static const passwordChanged =
      'Votre mot de passe a changé. Veuillez vous reconnecter.';
  static const forbidden = "Vous n'avez pas accès à cette ressource.";
  static const notFound = 'Élément introuvable.';
  static const configuration = 'Configuration du serveur invalide.';
  static const generic = 'Une erreur est survenue. Veuillez réessayer.';
}

/// Maps any error to a French message suitable for the UI.
String errorMessage(Object error) {
  if (error is NetworkException) return ErrorMessages.network;
  if (error is ConfigurationException) return ErrorMessages.configuration;
  if (error is ApiException) {
    switch (error.code) {
      case 'invalid_credentials':
      case 'identifier_unknown':
        return ErrorMessages.invalidCredentials;
      case 'account_inactive':
        return ErrorMessages.inactive;
      case 'directory_unavailable':
        return ErrorMessages.server;
      case 'throttled':
        final wait = error.retryAfter;
        return error.detail ??
            (wait == null
                ? 'Trop de tentatives. Veuillez réessayer plus tard.'
                : 'Trop de tentatives. Réessayez dans $wait s.');
    }
    if (error.isServerError) return ErrorMessages.server;
    final detail = error.detail;
    if (detail != null && detail.trim().isNotEmpty) return detail;
    if (error.isUnauthorized) return ErrorMessages.sessionExpired;
    if (error.isForbidden) return ErrorMessages.forbidden;
    if (error.isNotFound) return ErrorMessages.notFound;
    return ErrorMessages.generic;
  }
  return ErrorMessages.generic;
}

/// Message used by the login screen (legacy AuthenticationAct behaviour).
///
/// Returns `(message, isFieldError)`: credential errors are shown under the
/// password field, everything else as a toast/snackbar.
({String message, bool onPasswordField}) loginErrorMessage(Object error) {
  if (error is ApiException &&
      (error.code == 'invalid_credentials' ||
          error.code == 'identifier_unknown' ||
          (error.statusCode == 401 && error.code == null))) {
    return (message: ErrorMessages.invalidCredentials, onPasswordField: true);
  }
  if (error is ApiException &&
      (error.code == 'account_inactive' || error.statusCode == 403)) {
    return (message: ErrorMessages.inactive, onPasswordField: false);
  }
  if (error is ApiException && error.code == 'throttled') {
    return (message: errorMessage(error), onPasswordField: false);
  }
  if (error is NetworkException) {
    return (message: ErrorMessages.network, onPasswordField: false);
  }
  return (message: ErrorMessages.server, onPasswordField: false);
}
