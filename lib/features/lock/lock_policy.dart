import '../../core/storage/lock_settings_store.dart';

/// Pure decision: must the app show the lock screen?
///
/// * never without a session (nothing to protect) or with the lock off,
/// * cold start ([pausedAt] `null`, [coldStart] `true`): always,
/// * resume: when the app spent at least [delay] in the background
///   ([LockDelay.immediate]: any time in the background).
abstract final class LockPolicy {
  static bool shouldLock({
    required bool enabled,
    required LockDelay delay,
    required DateTime? pausedAt,
    required DateTime now,
    required bool hasSession,
    bool coldStart = false,
  }) {
    if (!enabled || !hasSession) return false;
    if (coldStart) return true;
    if (pausedAt == null) return false; // never went to the background
    if (delay == LockDelay.immediate) return true;
    return now.difference(pausedAt) >= delay.duration;
  }
}
