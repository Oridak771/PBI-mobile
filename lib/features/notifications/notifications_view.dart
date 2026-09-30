import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/notification.dart';
import 'notifications_controller.dart';

/// "Notification" tab: "Nouveau" (is_new) and "Déjà vu" (older) sections.
class NotificationsView extends ConsumerWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final page = async.value;
    if (page == null) {
      if (async.hasError) {
        return Center(
          child: RetryMessage(
            message: errorMessage(async.error!),
            onRetry: () => ref.invalidate(notificationsProvider),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    final controller = ref.read(notificationsProvider.notifier);
    Future<void> run(Future<String?> action) async {
      final error = await action;
      if (error != null && context.mounted) showToast(context, error);
    }

    final recent = page.recent;
    final older = page.older;
    final hasUnread = page.notifications.any((n) => !n.isRead);
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.only(top: 5, bottom: 10),
        children: [
          Row(
            children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 20),
                  child: Text(
                    'Nouveau',
                    style: TextStyle(color: AppColors.blue, fontSize: 16),
                  ),
                ),
              ),
              if (hasUnread)
                TextButton(
                  onPressed: () => run(controller.markAllRead()),
                  child: const Text(
                    'Tout marquer comme lu',
                    style: TextStyle(color: AppColors.blueGreen, fontSize: 13),
                  ),
                ),
            ],
          ),
          if (recent.isEmpty)
            const EmptyText(
              'Aucune nouvelle notification',
              color: AppColors.blue,
              padding: 20,
            ),
          for (final n in recent)
            NotificationRow(
              key: ValueKey('n${n.id}'),
              notification: n,
              onTap: () => run(controller.markRead(n.id)),
            ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
            color: AppColors.surface,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 20, top: 4, bottom: 4),
            child: Text(
              'Déjà vu',
              style: TextStyle(color: AppColors.greyText, fontSize: 16),
            ),
          ),
          if (older.isEmpty)
            const EmptyText('Aucune notification', padding: 20),
          for (final n in older)
            NotificationRow(
              key: ValueKey('n${n.id}'),
              notification: n,
              onTap: () => run(controller.markRead(n.id)),
            ),
        ],
      ),
    );
  }
}

/// Legacy row_item_notification.xml.
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = notification.isRead ? AppColors.greyText : AppColors.blue;
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: color, fontSize: 14),
                      ),
                    ),
                    Text(
                      relativeTimeFr(notification.createdAt),
                      style: TextStyle(color: color, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: color,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 5, 5, 10),
                child: Text(
                  notification.message,
                  style: const TextStyle(color: AppColors.gray, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
