import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/security/biometric_auth.dart';
import '../../core/storage/lock_settings_store.dart';
import 'lock_policy.dart';

/// Prompt texts (Android BiometricPrompt description).
abstract final class LockPrompts {
  static const unlock = 'Déverrouiller Portail BI';
  static const enable = 'Confirmez pour activer le verrouillage par empreinte';
  static const login = 'Connexion à Portail BI';
}

class AppLockState {
  const AppLockState({
    this.loaded = false,
    this.settings = const LockSettings(),
    this.locked = false,
  });

  /// Settings read from the store.
  final bool loaded;
  final LockSettings settings;

  /// The lock screen covers the app.
  final bool locked;

  bool get enabled => settings.enabled;
  LockDelay get delay => settings.delay;

  AppLockState copyWith({bool? loaded, LockSettings? settings, bool? locked}) =>
      AppLockState(
        loaded: loaded ?? this.loaded,
        settings: settings ?? this.settings,
        locked: locked ?? this.locked,
      );
}

/// App lock ("Verrouillage par empreinte").
///
/// The decision itself is [LockPolicy]; this controller feeds it with the
/// settings, the time the app went to the background and the session.
class AppLockController extends Notifier<AppLockState> {
  DateTime? _pausedAt;
  Future<bool>? _authenticating;
  final _waiters = <Completer<void>>[];

  @override
  AppLockState build() {
    ref.onDispose(_releaseWaiters);
    return const AppLockState();
  }

  LockSettingsStore get _store => ref.read(lockSettingsStoreProvider);
  DateTime _now() => ref.read(clockProvider)();

  /// Reads the settings once (splash).
  Future<void> load() async {
    if (state.loaded) return;
    try {
      final settings = await _store.load();
      state = state.copyWith(loaded: true, settings: settings);
    } catch (e) {
      debugPrint('Lock settings unavailable: $e');
      state = state.copyWith(loaded: true);
    }
  }

  /// Cold start with a stored session: locks when enabled. Returns [locked].
  bool lockOnColdStart({required bool hasSession}) {
    final lock = LockPolicy.shouldLock(
      enabled: state.enabled,
      delay: state.delay,
      pausedAt: null,
      now: _now(),
      hasSession: hasSession,
      coldStart: true,
    );
    if (lock) _lock();
    return state.locked;
  }

  /// App hidden / paused: remembers when (the first time only).
  void onBackground() {
    // The PIN fallback of the prompt pauses the activity: not a real exit.
    if (_authenticating != null) return;
    _pausedAt ??= _now();
  }

  /// App resumed: locks when it stayed long enough in the background.
  void onResumed({required bool hasSession}) {
    if (_authenticating != null) return;
    final pausedAt = _pausedAt;
    _pausedAt = null;
    final lock = LockPolicy.shouldLock(
      enabled: state.enabled,
      delay: state.delay,
      pausedAt: pausedAt,
      now: _now(),
      hasSession: hasSession,
    );
    if (lock) _lock();
  }

  void _lock() {
    if (state.locked) return;
    // Hide the keyboard of the screen underneath.
    FocusManager.instance.primaryFocus?.unfocus();
    state = state.copyWith(locked: true);
  }

  /// The system prompt is on screen.
  bool get authenticating => _authenticating != null;

  /// System prompt, one at a time (a second call joins the first one).
  /// While it is shown, background / resume events are ignored.
  Future<bool> authenticate(String reason) {
    final running = _authenticating;
    if (running != null) return running;
    final attempt = _runAuthentication(reason);
    _authenticating = attempt;
    return attempt;
  }

  Future<bool> _runAuthentication(String reason) async {
    try {
      return await ref.read(biometricAuthProvider).authenticate(reason);
    } catch (_) {
      return false;
    } finally {
      _authenticating = null;
      _pausedAt = null;
    }
  }

  /// "Déverrouiller".
  Future<bool> unlock() async {
    if (!state.locked) return true;
    if (!authenticating && !await _deviceCanAuthenticate()) {
      // Fingerprints and PIN removed since the lock was enabled: the prompt
      // can never succeed, don't lock the user out.
      await disable();
      _unlocked();
      return true;
    }
    final ok = await authenticate(LockPrompts.unlock);
    if (ok) _unlocked();
    return ok;
  }

  Future<bool> _deviceCanAuthenticate() async {
    try {
      return (await ref.read(biometricAuthProvider).status()).isAvailable;
    } catch (_) {
      return true; // unknown: keep the lock
    }
  }

  /// Session ended (logout, 401): nothing left to protect.
  void release() {
    _pausedAt = null;
    if (state.locked) _unlocked();
  }

  void _unlocked() {
    state = state.copyWith(locked: false);
    _releaseWaiters();
  }

  void _releaseWaiters() {
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _waiters.clear();
  }

  /// Completes once the app is unlocked (or the session ended).
  Future<void> whenUnlocked() {
    if (!state.locked) return Future.value();
    final waiter = Completer<void>();
    _waiters.add(waiter);
    return waiter.future;
  }

  /// "Verrouillage par empreinte" on: requires a successful prompt first.
  Future<bool> enable() async {
    final ok = await authenticate(LockPrompts.enable);
    if (!ok) return false;
    await _save(state.settings.copyWith(enabled: true, offered: true));
    return true;
  }

  Future<void> disable() => _save(state.settings.copyWith(enabled: false));

  Future<void> setDelay(LockDelay delay) =>
      _save(state.settings.copyWith(delay: delay));

  /// The enrolment sheet was shown ("Plus tard" or dismissed).
  Future<void> markOffered() => _save(state.settings.copyWith(offered: true));

  /// After a login: should the "Activer le déverrouillage par empreinte ?"
  /// sheet be offered?
  Future<bool> shouldOfferEnrolment() async {
    await load();
    if (state.enabled || state.settings.offered) return false;
    try {
      final status = await ref.read(biometricStatusProvider.future);
      return status == BiometricStatus.biometrics;
    } catch (_) {
      return false;
    }
  }

  Future<void> _save(LockSettings settings) async {
    state = state.copyWith(settings: settings, loaded: true);
    try {
      await _store.save(settings);
    } catch (e) {
      debugPrint('Lock settings not saved: $e');
    }
  }
}

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);
