import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/biometric_auth.dart';
import '../../core/storage/lock_settings_store.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/common.dart';
import '../lock/app_lock_controller.dart';
import 'settings_view.dart';
import '../../core/widgets/glass.dart';

/// "Sécurité": fingerprint lock and its delay.
class SecuritySettings extends ConsumerStatefulWidget {
  const SecuritySettings({super.key});

  @override
  ConsumerState<SecuritySettings> createState() => _SecuritySettingsState();
}

class _SecuritySettingsState extends ConsumerState<SecuritySettings> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(appLockProvider.notifier).load();
  }

  Future<void> _toggleLock(bool on) async {
    if (_busy) return;
    final lock = ref.read(appLockProvider.notifier);
    if (!on) return lock.disable();
    setState(() => _busy = true);
    final ok = await lock.enable();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) showToast(context, 'Verrouillage non activé.');
  }

  Future<void> _pickDelay(LockDelay current) async {
    final picked = await showGlassSheet<LockDelay>(
      context: context,
      builder: (sheetContext) {
        final palette = sheetContext.palette;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    'Délai de verrouillage',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SettingsGroup(
                  children: [
                    for (final delay in LockDelay.values)
                      InkWell(
                        key: Key('lock-delay-${delay.name}'),
                        onTap: () => Navigator.pop(sheetContext, delay),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 52),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    delay.label,
                                    style: TextStyle(
                                      color: palette.text,
                                      fontSize: 15,
                                      fontWeight: delay == current
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (delay == current)
                                  Icon(
                                    Icons.check_rounded,
                                    color: palette.primaryText,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) await ref.read(appLockProvider.notifier).setDelay(picked);
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    final status = ref.watch(biometricStatusProvider);
    final available = status.value?.isAvailable ?? false;
    final checking = status.isLoading && !status.hasValue;
    return SettingsGroup(
      children: [
        SettingsSwitchEntry(
          'Verrouillage par empreinte',
          key: const Key('lock-switch'),
          icon: Icons.fingerprint_rounded,
          subtitle: !available && !checking
              ? 'Aucune empreinte ou code configuré sur ce téléphone'
              : 'Déverrouillage au retour dans l’application',
          value: lock.enabled,
          // Turning it off stays possible even if the PIN was removed since.
          onChanged: !_busy && (available || lock.enabled) ? _toggleLock : null,
        ),
        if (lock.enabled)
          SettingsValueEntry(
            'Délai de verrouillage',
            key: const Key('lock-delay'),
            icon: Icons.timer_outlined,
            value: lock.delay.label,
            onTap: () => _pickDelay(lock.delay),
          ),
      ],
    );
  }
}
