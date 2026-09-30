import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
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
    backgroundColor: AppColors.black,
    body: SafeArea(
      child: Column(
        children: [
          const ScreenHeader(title: 'Historique détaillé', titleSize: 20),
          Expanded(
            child: FutureBuilder<UserHistory>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
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
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 10),
                    children: [
                      _UserBlock(user: data.user),
                      if (data.history.isEmpty)
                        const EmptyText('Aucune consultation ces 30 derniers jours'),
                      for (final item in data.history) HistoryDetailRow(item: item),
                    ],
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: Row(
      children: [
        UserAvatar(
          size: 70,
          photoUrl: user.photoUrl,
          initials: user.initials,
          color: user.avatarColor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: const TextStyle(color: AppColors.gray, fontSize: 16),
              ),
              if (user.description.isNotEmpty)
                Text(
                  user.description,
                  style: const TextStyle(color: AppColors.tint, fontSize: 14),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Legacy row_item_historique_details.xml.
class HistoryDetailRow extends StatelessWidget {
  const HistoryDetailRow({super.key, required this.item});

  final HistoryItem item;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    elevation: 0,
    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.path, style: const TextStyle(color: AppColors.gray)),
          const SizedBox(height: 5),
          Text(
            formatHistoryLine(item.openedAt, item.durationSeconds),
            style: const TextStyle(color: AppColors.tint),
          ),
        ],
      ),
    ),
  );
}
