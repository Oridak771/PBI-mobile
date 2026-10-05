import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/biometric_auth.dart';
import '../auth/session_controller.dart';
import 'app_lock_controller.dart';
import 'lock_screen.dart';

/// Navigator of the lock overlay (its logout dialog lives there, above the
/// app).
final lockNavigatorKey = GlobalKey<NavigatorState>();

/// `MaterialApp.builder` layer: the app ([child], i.e. the root navigator)
/// with the lock screen stacked above it.
///
/// The app stays mounted underneath, so the current screen and the report
/// WebView keep their state; while locked it is hidden from accessibility
/// services and covered by an opaque screen.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onLifecycle(AppLifecycleState state) {
    final lock = ref.read(appLockProvider.notifier);
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        lock.onBackground();
      case AppLifecycleState.resumed:
        // A fingerprint / PIN may have been set up in the system settings.
        ref.invalidate(biometricStatusProvider);
        lock.onResumed(hasSession: ref.read(sessionProvider).isAuthenticated);
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(appLockProvider.select((s) => s.locked));
    return Stack(
      fit: StackFit.expand,
      children: [
        // Hidden app: no animations, nothing for accessibility services.
        TickerMode(
          enabled: !locked,
          child: ExcludeSemantics(excluding: locked, child: widget.child),
        ),
        if (locked)
          HeroControllerScope.none(
            child: Navigator(
              key: lockNavigatorKey,
              onGenerateRoute: (_) => PageRouteBuilder<void>(
                pageBuilder: (_, _, _) => const LockScreen(),
                transitionDuration: Duration.zero,
              ),
            ),
          ),
      ],
    );
  }
}

/// Blocks the Android back button / gesture while the app is locked.
///
/// Registered by `CbiApp` before `MaterialApp`, so it sees the back events
/// before the root navigator (observers are called in registration order).
class LockBackButtonGuard with WidgetsBindingObserver {
  LockBackButtonGuard(this.isLocked);

  final bool Function() isLocked;

  @override
  Future<bool> didPopRoute() async {
    if (!isLocked()) return false;
    // Closes the logout dialog of the lock screen, never the app screens.
    await lockNavigatorKey.currentState?.maybePop();
    return true;
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) => isLocked();

  @override
  void handleCommitBackGesture() => lockNavigatorKey.currentState?.maybePop();
}
