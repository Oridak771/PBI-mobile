import 'package:cbi_mobile/core/storage/lock_settings_store.dart';
import 'package:cbi_mobile/features/lock/lock_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 30, 10);

  bool decide({
    bool enabled = true,
    LockDelay delay = LockDelay.oneMinute,
    Duration? away,
    bool hasSession = true,
    bool coldStart = false,
  }) => LockPolicy.shouldLock(
    enabled: enabled,
    delay: delay,
    pausedAt: away == null ? null : now.subtract(away),
    now: now,
    hasSession: hasSession,
    coldStart: coldStart,
  );

  group('LockPolicy', () {
    test('never locks when disabled or without a session', () {
      for (final delay in LockDelay.values) {
        expect(decide(enabled: false, delay: delay, away: const Duration(hours: 1)), isFalse);
        expect(decide(hasSession: false, delay: delay, away: const Duration(hours: 1)), isFalse);
        expect(decide(enabled: false, delay: delay, coldStart: true), isFalse);
        expect(decide(hasSession: false, delay: delay, coldStart: true), isFalse);
      }
    });

    test('cold start with a session always locks, whatever the delay', () {
      for (final delay in LockDelay.values) {
        expect(decide(delay: delay, coldStart: true), isTrue);
      }
    });

    test('resume without having been in the background does not lock', () {
      for (final delay in LockDelay.values) {
        expect(decide(delay: delay), isFalse);
      }
    });

    test('"Immédiat" locks after any time in the background', () {
      expect(decide(delay: LockDelay.immediate, away: Duration.zero), isTrue);
      expect(decide(delay: LockDelay.immediate, away: const Duration(seconds: 1)), isTrue);
    });

    test('timed delays lock from the delay on, not before', () {
      for (final delay in [
        LockDelay.oneMinute,
        LockDelay.fiveMinutes,
        LockDelay.fifteenMinutes,
      ]) {
        final d = delay.duration;
        expect(decide(delay: delay, away: d - const Duration(seconds: 1)), isFalse, reason: delay.label);
        expect(decide(delay: delay, away: d), isTrue, reason: delay.label);
        expect(decide(delay: delay, away: d + const Duration(minutes: 3)), isTrue, reason: delay.label);
      }
    });

    test('delays: labels, durations and persistence', () {
      expect(LockDelay.values.map((d) => d.label), ['Immédiat', '1 min', '5 min', '15 min']);
      expect(LockDelay.fallback, LockDelay.oneMinute);
      for (final d in LockDelay.values) {
        expect(LockDelay.fromSeconds(d.duration.inSeconds), d);
      }
      expect(LockDelay.fromSeconds(null), LockDelay.oneMinute);
      expect(LockDelay.fromSeconds(42), LockDelay.oneMinute);
    });
  });
}
