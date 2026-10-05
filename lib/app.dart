import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/errors/app_exception.dart';
import 'core/layout/adaptive.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/session_controller.dart';
import 'features/lock/app_lock_controller.dart';
import 'features/lock/app_lock_gate.dart';
import 'features/notifications/local_notifications.dart';
import 'features/notifications/notifications_controller.dart';
import 'features/reports/catalog_controller.dart';
import 'features/shell/shell_controller.dart';
import 'features/splash/splash_screen.dart';
import 'features/tickets/tickets_controller.dart';

/// Riverpod automatic retry: only transient network failures are retried.
Duration? providerRetry(int retryCount, Object error) =>
    error is NetworkException && retryCount < 3
    ? Duration(seconds: 2 << retryCount)
    : null;

final appNavigatorKey = GlobalKey<NavigatorState>();
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

class CbiApp extends ConsumerStatefulWidget {
  const CbiApp({super.key, this.home = const SplashScreen()});

  final Widget home;

  @override
  ConsumerState<CbiApp> createState() => _CbiAppState();
}

class _CbiAppState extends ConsumerState<CbiApp> {
  late final LockBackButtonGuard _backGuard;

  @override
  void initState() {
    super.initState();
    // Before MaterialApp registers its own observer: sees back events first.
    _backGuard = LockBackButtonGuard(() => ref.read(appLockProvider).locked);
    WidgetsBinding.instance.addObserver(_backGuard);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_backGuard);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Session ended (logout or any 401): wipe user data, back to login.
    ref.listen(sessionProvider, (previous, next) {
      if (previous?.isAuthenticated != true ||
          next.status != SessionStatus.unauthenticated) {
        return;
      }
      ref.read(notificationPlatformProvider).stopBackgroundPolling();
      ref.invalidate(catalogProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
      ref.invalidate(shellProvider);
      ref.invalidate(ticketChoicesProvider);
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      // "Mot de passe changé" is shown by the login screen itself.
      if (next.expired && !next.passwordChanged) {
        appMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text(ErrorMessages.sessionExpired)),
        );
      }
    });

    return MaterialApp(
      title: 'GSH - CBI',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appMessengerKey,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ref.watch(themeModeProvider),
      builder: (context, child) => clampTextScale(
        context,
        themedSystemBars(
          context,
          AppLockGate(child: child ?? const SizedBox.shrink()),
        ),
      ),
      home: widget.home,
    );
  }
}

/// `MaterialApp.builder`: status / navigation bar icons follow the theme.
Widget themedSystemBars(BuildContext context, Widget? child) =>
    AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayFor(context.palette),
      child: child ?? const SizedBox.shrink(),
    );
