import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/layout/adaptive.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/skeleton.dart';
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
      return const SkeletonList();
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
      child: CenteredContent(
        builder: (context, gutter) => ListView(
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 24),
        children: [
          SectionHeader(
            'Nouveau',
            count: recent.isEmpty ? null : recent.length,
            padding: const EdgeInsets.fromLTRB(2, 8, 0, 6),
            trailing: hasUnread
                ? TextButton(
                    onPressed: () => run(controller.markAllRead()),
                    child: const Text(
                      'Tout marquer comme lu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : const SizedBox(height: 40),
          ),
          if (recent.isEmpty)
            const EmptyText(
              'Aucune nouvelle notification',
              padding: 20,
              icon: Icons.notifications_none_rounded,
            ),
          for (final n in recent)
            NotificationRow(
              key: ValueKey('n${n.id}'),
              notification: n,
              onTap: () => run(controller.markRead(n.id)),
            ),
          SectionHeader(
            'Déjà vu',
            count: older.isEmpty ? null : older.length,
            padding: const EdgeInsets.fromLTRB(2, 20, 0, 10),
          ),
          if (older.isEmpty) const EmptyText('Aucune notification', padding: 20),
          for (final n in older)
            NotificationRow(
              key: ValueKey('n${n.id}'),
              notification: n,
              onTap: () => run(controller.markRead(n.id)),
            ),
        ],
      ),
      ),
    );
  }
}

/// Notification card: kind icon, title (green + dot when unread), relative
/// time, message.
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  static IconData iconFor(String kind) => switch (kind) {
    'access' => Icons.key_rounded,
    'report' => Icons.insights_rounded,
    _ => Icons.info_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final unread = !notification.isRead;
    final titleColor = unread ? palette.primaryText : palette.textMuted;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: onTap,
      borderColor: unread ? palette.primary.withValues(alpha: 0.45) : null,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconWell(
            iconFor(notification.kind),
            color: unread ? palette.primaryText : palette.textSubtle,
            background: unread ? palette.primarySoft : palette.surfaceAlt,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 15,
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      relativeTimeFr(notification.createdAt),
                      style: TextStyle(color: palette.textSubtle, fontSize: 12),
                    ),
                    if (unread) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: palette.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: TextStyle(
                    color: unread ? palette.text : palette.textMuted,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
