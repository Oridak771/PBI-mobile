import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/layout/adaptive.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/history.dart';
import '../auth/session_controller.dart';

/// Legacy HistoriqueDetails: last 30 days of one user.
///
/// Without [user], shows the current user's own history (`GET history/`).
class HistoryDetailsScreen extends ConsumerStatefulWidget {
  const HistoryDetailsScreen({super.key, this.user});

  final HistoryUser? user;

  @override
  ConsumerState<HistoryDetailsScreen> createState() =>
      _HistoryDetailsScreenState();
}

class _HistoryDetailsScreenState extends ConsumerState<HistoryDetailsScreen> {
  late Future<UserHistory> _future = _load();

  Future<UserHistory> _load() async {
    final repo = ref.read(repositoryProvider);
    final target = widget.user;
    if (target != null) return repo.fetchUserHistory(target.id);
    final me = ref.read(sessionProvider).user;
    final items = await repo.fetchMyHistory();
    return UserHistory(
      user: HistoryUser(
        id: me?.id ?? 0,
        name: me?.name ?? '',
        initials: me?.initials ?? '',
        description: me?.description ?? '',
        company: me?.company ?? '',
        photoUrl: me?.photoUrl,
        avatarColor: me?.avatarColor,
      ),
      history: items,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // Displayed by the FutureBuilder.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const ScreenHeader(title: 'Historique détaillé'),
          Expanded(
            child: FutureBuilder<UserHistory>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SkeletonList(count: 8);
                }
                if (snapshot.hasError) {
                  return Center(
                    child: RetryMessage(
                      message: errorMessage(snapshot.error!),
                      onRetry: _refresh,
                    ),
                  );
                }
                final data = snapshot.requireData;
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: CenteredContent(
                    builder: (context, gutter) => ListView(
                    padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 24),
                    children: [
                      _UserBlock(user: data.user),
                      SectionHeader(
                        'Consultations',
                        count: data.history.length,
                        padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
                      ),
                      if (data.history.isEmpty)
                        const EmptyText(
                          'Aucune consultation ces 30 derniers jours',
                          icon: Icons.history_rounded,
                        ),
                      for (final item in data.history) HistoryDetailRow(item: item),
                    ],
                  ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _UserBlock extends StatelessWidget {
  const _UserBlock({required this.user});

  final HistoryUser user;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          UserAvatar(
            size: 56,
            photoUrl: user.photoUrl,
            initials: user.initials,
            color: user.avatarColor,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (user.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.description,
                    style: TextStyle(color: palette.textMuted, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One consultation: report path, date, time and duration.
class HistoryDetailRow extends StatelessWidget {
  const HistoryDetailRow({super.key, required this.item});

  final HistoryItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const IconWell(Icons.insights_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.path,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatHistoryLine(item.openedAt, item.durationSeconds),
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
