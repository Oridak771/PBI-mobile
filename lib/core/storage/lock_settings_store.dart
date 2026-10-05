import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// "Délai de verrouillage": time spent in the background before the app
/// locks again.
enum LockDelay {
  immediate(Duration.zero, 'Immédiat'),
  oneMinute(Duration(minutes: 1), '1 min'),
  fiveMinutes(Duration(minutes: 5), '5 min'),
  fifteenMinutes(Duration(minutes: 15), '15 min');

  const LockDelay(this.duration, this.label);

  final Duration duration;
  final String label;

  static const fallback = LockDelay.oneMinute;

  static LockDelay fromSeconds(int? seconds) => LockDelay.values.firstWhere(
    (d) => d.duration.inSeconds == seconds,
    orElse: () => fallback,
  );
}

/// App lock preferences ("Paramètre → Sécurité").
class LockSettings {
  const LockSettings({
    this.enabled = false,
    this.delay = LockDelay.fallback,
    this.offered = false,
  });

  /// "Verrouillage par empreinte".
  final bool enabled;
  final LockDelay delay;

  /// The "Activer le déverrouillage par empreinte ?" sheet was already shown.
  final bool offered;

  LockSettings copyWith({bool? enabled, LockDelay? delay, bool? offered}) =>
      LockSettings(
        enabled: enabled ?? this.enabled,
        delay: delay ?? this.delay,
        offered: offered ?? this.offered,
      );
}

abstract class LockSettingsStore {
  Future<LockSettings> load();
  Future<void> save(LockSettings settings);
}

/// `flutter_secure_storage`: a local attacker cannot switch the lock off by
/// editing plain shared preferences.
class SecureLockSettingsStore implements LockSettingsStore {
  SecureLockSettingsStore({FlutterSecureStorage? secure})
    : _secure = secure ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  static const kEnabled = 'app_lock_enabled';
  static const kDelay = 'app_lock_delay_seconds';
  static const kOffered = 'app_lock_offered';

  @override
  Future<LockSettings> load() async => LockSettings(
    enabled: await _secure.read(key: kEnabled) == 'true',
    delay: LockDelay.fromSeconds(int.tryParse(await _secure.read(key: kDelay) ?? '')),
    offered: await _secure.read(key: kOffered) == 'true',
  );

  @override
  Future<void> save(LockSettings settings) async {
    await _secure.write(key: kEnabled, value: '${settings.enabled}');
    await _secure.write(key: kDelay, value: '${settings.delay.duration.inSeconds}');
    await _secure.write(key: kOffered, value: '${settings.offered}');
  }
}

/// In-memory store (tests and demo mode).
class MemoryLockSettingsStore implements LockSettingsStore {
  MemoryLockSettingsStore([this.settings = const LockSettings()]);

  LockSettings settings;

  @override
  Future<LockSettings> load() async => settings;

  @override
  Future<void> save(LockSettings settings) async => this.settings = settings;
}
