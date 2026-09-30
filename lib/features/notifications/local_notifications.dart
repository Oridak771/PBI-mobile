import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/notification.dart';
import 'notification_worker.dart';

/// Local notifications + background polling (no Firebase: WorkManager polls
/// the CBI platform, see [callbackDispatcher]).
abstract class NotificationPlatform {
  /// Initialises the plugin; returns `true` when the app was launched by a
  /// tap on one of our notifications.
  Future<bool> init();

  /// Emits when a notification is tapped while the app is running.
  Stream<void> get taps;

  /// Android 13+ `POST_NOTIFICATIONS` runtime permission.
  Future<void> requestPermission();

  /// Registers the 15-minute WorkManager task.
  Future<void> startBackgroundPolling();
  Future<void> stopBackgroundPolling();
}

class NoopNotificationPlatform implements NotificationPlatform {
  @override
  Future<bool> init() async => false;
  @override
  Stream<void> get taps => const Stream.empty();
  @override
  Future<void> requestPermission() async {}
  @override
  Future<void> startBackgroundPolling() async {}
  @override
  Future<void> stopBackgroundPolling() async {}
}

class AndroidNotificationPlatform implements NotificationPlatform {
  AndroidNotificationPlatform._();
  static final instance = AndroidNotificationPlatform._();

  final _taps = StreamController<void>.broadcast();
  bool _initialised = false;

  @override
  Stream<void> get taps => _taps.stream;

  @override
  Future<bool> init() async {
    if (_initialised) return false;
    _initialised = true;
    try {
      await Workmanager().initialize(callbackDispatcher);
    } catch (e) {
      debugPrint('Workmanager init failed: $e');
    }
    final plugin = await LocalNotifications.initialise(
      onTap: (_) => _taps.add(null),
    );
    final launch = await plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp ?? false;
  }

  @override
  Future<void> requestPermission() async {
    try {
      await LocalNotifications.plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  @override
  Future<void> startBackgroundPolling() async {
    try {
      await Workmanager().registerPeriodicTask(
        notificationTaskUniqueName,
        notificationTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('Workmanager registration failed: $e');
    }
  }

  @override
  Future<void> stopBackgroundPolling() async {
    try {
      await Workmanager().cancelByUniqueName(notificationTaskUniqueName);
      await LocalNotifications.plugin.cancelAll();
    } catch (e) {
      debugPrint('Workmanager cancel failed: $e');
    }
  }
}

final notificationPlatformProvider = Provider<NotificationPlatform>(
  (ref) => !kIsWeb && Platform.isAndroid
      ? AndroidNotificationPlatform.instance
      : NoopNotificationPlatform(),
);

/// `flutter_local_notifications` wrapper shared by the UI and the worker.
abstract final class LocalNotifications {
  static const channelId = 'cbi_notifications';
  static const channelName = 'Notifications CBI';
  static const payload = 'notifications';

  static final plugin = FlutterLocalNotificationsPlugin();

  static Future<FlutterLocalNotificationsPlugin> initialise({
    void Function(NotificationResponse)? onTap,
  }) async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_pbi'),
      ),
      onDidReceiveNotificationResponse: onTap,
    );
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: 'Notifications de la plateforme CBI',
            importance: Importance.high,
          ),
        );
    return plugin;
  }

  static Future<void> show(AppNotification n) => plugin.show(
    id: n.id,
    title: n.title,
    body: n.message,
    payload: payload,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Notifications de la plateforme CBI',
        importance: Importance.high,
        priority: Priority.high,
        color: AppColors.notification,
        styleInformation: BigTextStyleInformation(
          n.message,
          contentTitle: n.title,
        ),
      ),
    ),
  );
}
