import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/errors/app_exception.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/session_controller.dart';
import 'features/notifications/local_notifications.dart';
import 'features/notifications/notifications_controller.dart';
import 'features/reports/catalog_controller.dart';
import 'features/shell/shell_controller.dart';
import 'features/splash/splash_screen.dart';

/// Riverpod automatic retry: only transient network failures are retried.
Duration? providerRetry(int retryCount, Object error) =>
    error is NetworkException && retryCount < 3
    ? Duration(seconds: 2 << retryCount)
    : null;

final appNavigatorKey = GlobalKey<NavigatorState>();
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

class CbiApp extends ConsumerWidget {
  const CbiApp({super.key, this.home = const SplashScreen()});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      if (next.expired) {
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
      theme: buildAppTheme(),
      home: home,
    );
  }
}
