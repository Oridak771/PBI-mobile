import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/layout/adaptive.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/notification.dart';
import 'notifications_controller.dart';

/// Opens the notifications screen (bell of Accueil, notification taps).
Future<void> openNotifications(
  BuildContext context,
  WidgetRef ref, {
  bool refresh = true,
}) {
  if (refresh) ref.read(notificationsProvider.notifier).refresh();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
  );
}

/// Full screen of the notifications (glass header + [NotificationsView]).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => const GlassScaffold(
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          ScreenHeader(title: 'Notifications'),
          Expanded(child: NotificationsView()),
        ],
      ),
    ),
  );
}

/// Notifications: "Nouveau" (is_new) and "Déjà vu" (older) sections.
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
            padding: const EdgeInsets.fromLTRB(4, 8, 0, 6),
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
            padding: const EdgeInsets.fromLTRB(4, 20, 0, 10),
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
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onTap,
      borderColor: unread ? palette.primary.withValues(alpha: 0.45) : null,
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconWell(
            iconFor(notification.kind),
            color: unread ? palette.primaryText : palette.textMuted,
            background: unread ? palette.primarySoft : palette.glassSelected,
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
                          fontSize: 13.5,
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      relativeShortFr(notification.createdAt),
                      style: TextStyle(color: palette.textMuted, fontSize: 10),
                    ),
                    if (unread) ...[
                      const SizedBox(width: 6),
                      GlowDot(color: palette.primaryText, size: 7, glow: 6),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: TextStyle(
                    color: unread ? palette.text : palette.textMuted,
                    fontSize: 12.5,
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
