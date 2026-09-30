import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/assets.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/asset_slots.dart';
import '../../data/models/remote_config.dart';
import '../auth/login_screen.dart';
import '../auth/session_controller.dart';
import '../notifications/local_notifications.dart';
import '../shell/shell_controller.dart';
import '../shell/shell_screen.dart';

/// Legacy CheckAuth: version check, then shell (stored token) or login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    var fromNotification = false;
    try {
      fromNotification = await ref.read(notificationPlatformProvider).init();
    } catch (_) {}

    // Don't keep the splash for the full HTTP timeout when the server is down.
    final config = await ref
        .read(remoteConfigProvider.future)
        .timeout(const Duration(seconds: 10), onTimeout: RemoteConfig.new);
    String version;
    try {
      version = await ref.read(appVersionProvider.future);
    } catch (_) {
      version = '0.0.0';
    }
    if (!mounted) return;
    if (isVersionLower(version, config.minVersion)) {
      await showUpdateRequiredDialog(context, config);
      return; // blocking: the user must update
    }

    bool loggedIn;
    try {
      loggedIn = await ref.read(sessionProvider.notifier).restore();
    } catch (_) {
      loggedIn = false;
    }
    if (!mounted) return;
    if (loggedIn && fromNotification) {
      ref.read(shellProvider.notifier).selectTab(ShellTab.notifications);
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) =>
            loggedIn ? const ShellScreen() : const LoginScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.black,
    body: Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.all(80),
            child: LogoSlot(
              asset: AppAssets.splashLogo,
              fallbackText: 'CBI',
              fontSize: 72,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: 100),
            child: CircularProgressIndicator(),
          ),
        ),
      ],
    ),
  );
}

/// Legacy non-cancellable "Mise à jour requise" dialog.
Future<void> showUpdateRequiredDialog(
  BuildContext context,
  RemoteConfig config,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => PopScope(
    canPop: false,
    child: AlertDialog(
      backgroundColor: AppColors.sheet,
      title: const Text(
        'Mise à jour requise',
        style: TextStyle(color: AppColors.black),
      ),
      content: const Text(
        "Merci de mettre à jour l'application GSH-CBI .",
        style: TextStyle(color: AppColors.black),
      ),
      actions: [
        TextButton(
          onPressed: () {
            final uri = Uri.tryParse(config.downloadUrl);
            if (uri != null && uri.hasScheme) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: const Text(
            'Mettre à Jour',
            style: TextStyle(color: AppColors.blueGreen),
          ),
        ),
      ],
    ),
  ),
);
