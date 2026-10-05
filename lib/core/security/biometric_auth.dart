import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

/// What the phone offers to unlock the app.
enum BiometricStatus {
  /// At least one fingerprint / face is enrolled.
  biometrics,

  /// No biometric enrolled, but a PIN / pattern / password is set.
  deviceCredential,

  /// Nothing configured (or no hardware / plugin): the lock cannot be used.
  unavailable;

  /// `true` when [BiometricAuth.authenticate] can succeed.
  bool get isAvailable => this != BiometricStatus.unavailable;
}

/// Local (on-device) authentication, behind an interface so tests can fake
/// it.
abstract class BiometricAuth {
  Future<BiometricStatus> status();

  /// Shows the system prompt; `true` when the user authenticated.
  /// Never throws (cancel, lockout, errors → `false`).
  Future<bool> authenticate(String reason);
}

/// [BiometricAuth] backed by `local_auth` (Android BiometricPrompt).
///
/// `biometricOnly: false`: the device PIN / pattern is always accepted as a
/// fallback, so a user whose fingerprint stops working is never locked out.
class LocalBiometricAuth implements BiometricAuth {
  LocalBiometricAuth([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<BiometricStatus> status() async {
    try {
      if (!await _auth.isDeviceSupported()) return BiometricStatus.unavailable;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isEmpty
          ? BiometricStatus.deviceCredential
          : BiometricStatus.biometrics;
    } on LocalAuthException {
      return BiometricStatus.unavailable;
    } on PlatformException {
      return BiometricStatus.unavailable;
    } on MissingPluginException {
      return BiometricStatus.unavailable;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Déverrouiller Portail BI',
            signInHint: 'Utilisez votre empreinte ou le code du téléphone',
            cancelButton: 'Annuler',
          ),
        ],
        biometricOnly: false,
        // No extra "Confirmer" tap after a face unlock.
        sensitiveTransaction: false,
        // Former `stickyAuth`: survive a trip to the background.
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      debugPrint('Biometric authentication failed: ${e.code}');
      return false;
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication failed: $e');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

final biometricAuthProvider = Provider<BiometricAuth>(
  (ref) => LocalBiometricAuth(),
);

/// Current capability of the phone; invalidated on resume (the user may have
/// enrolled a fingerprint in the system settings meanwhile).
final biometricStatusProvider = FutureProvider<BiometricStatus>(
  (ref) => ref.watch(biometricAuthProvider).status(),
);
