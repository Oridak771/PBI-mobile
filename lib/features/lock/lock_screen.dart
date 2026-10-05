import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/assets.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/asset_slots.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/user.dart';
import '../auth/session_controller.dart';
import '../settings/settings_view.dart';
import 'app_lock_controller.dart';
import '../../core/widgets/glass.dart';

/// Profile kept with the session (cold start: `me/` not refreshed yet).
final storedUserProvider = FutureProvider.autoDispose<User?>((ref) async {
  try {
    return (await ref.read(sessionStoreProvider).read())?.user;
  } catch (_) {
    return null;
  }
});

/// "Application verrouillée": covers the whole app until the fingerprint (or
/// the device PIN) is confirmed. The prompt opens by itself when the screen
/// appears and when the app comes back to the foreground.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _failed = false;

  /// The app really went to the background (not just behind the prompt:
  /// a cancelled prompt must not reopen itself in a loop).
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        if (!ref.read(appLockProvider.notifier).authenticating) {
          _wasInBackground = true;
        }
      },
      onResume: () {
        if (!_wasInBackground) return;
        _wasInBackground = false;
        _unlock();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (!mounted) return;
    final ok = await ref.read(appLockProvider.notifier).unlock();
    if (mounted && !ok) setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final brightness = Theme.of(context).brightness;
    final session = ref.watch(sessionProvider);
    final user = session.user ?? ref.watch(storedUserProvider).value;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayFor(palette),
      child: Scaffold(
        key: const Key('lock-screen'),
        backgroundColor: palette.background,
        body: GlassBackground(
          child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 56,
                      child: LogoSlot(
                        asset: AppAssets.pbiMark(brightness),
                        fallbackText: 'PBI',
                        fontSize: 36,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Center(
                      child: UserAvatar(
                        size: 88,
                        brand: true,
                        // The photo needs a live token: initials at cold start.
                        photoUrl: session.isAuthenticated ? user?.photoUrl : null,
                        initials: user?.initials ?? '',
                        color: user?.avatarColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if ((user?.name ?? '').isNotEmpty)
                      Text(
                        user!.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: palette.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Application verrouillée',
                          style: TextStyle(color: palette.textMuted, fontSize: 15),
                        ),
                      ],
                    ),
                    if (_failed) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Touchez « Déverrouiller » pour réessayer.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.textSubtle, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 40),
                    GradientButton(
                      key: const Key('lock-unlock'),
                      label: 'Déverrouiller',
                      icon: Icons.fingerprint_rounded,
                      onPressed: _unlock,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      key: const Key('lock-logout'),
                      onPressed: () => confirmLogout(context, ref),
                      style: TextButton.styleFrom(foregroundColor: palette.danger),
                      child: const Text('Se déconnecter'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}

/// "Activer le déverrouillage par empreinte ?" (offered once, after the first
/// login on a phone with an enrolled fingerprint).
Future<void> showEnableLockSheet(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  // Shown once: dismissing the sheet counts as "Plus tard".
  await container.read(appLockProvider.notifier).markOffered();
  if (!context.mounted) return;
  await showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _EnableLockSheet(),
  );
}

class _EnableLockSheet extends ConsumerStatefulWidget {
  const _EnableLockSheet();

  @override
  ConsumerState<_EnableLockSheet> createState() => _EnableLockSheetState();
}

class _EnableLockSheetState extends ConsumerState<_EnableLockSheet> {
  bool _busy = false;

  Future<void> _enable() async {
    setState(() => _busy = true);
    final ok = await ref.read(appLockProvider.notifier).enable();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Verrouillage par empreinte activé')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: IconWell(Icons.fingerprint_rounded, size: 56)),
            const SizedBox(height: 16),
            Text(
              'Activer le déverrouillage par empreinte ?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.text,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "L'application se verrouille quand vous la quittez. "
              'Déverrouillez-la avec votre empreinte ou le code du téléphone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            GradientButton(
              key: const Key('enable-lock-accept'),
              label: 'Activer',
              icon: Icons.fingerprint_rounded,
              busy: _busy,
              onPressed: _enable,
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('enable-lock-later'),
              onPressed: _busy ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: palette.textMuted),
              child: const Text('Plus tard'),
            ),
          ],
        ),
      ),
    );
  }
}
