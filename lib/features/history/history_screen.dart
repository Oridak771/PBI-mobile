import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/legacy_dialog.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/history.dart';
import '../auth/session_controller.dart';
import 'history_details_screen.dart';

/// "Historique": admins see every user (legacy HistoriqueActivity), other
/// users go straight to their own detailed history.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(
      sessionProvider.select((s) => s.user?.isAdmin ?? false),
    );
    return isAdmin ? const _AdminHistoryScreen() : const HistoryDetailsScreen();
  }
}

class _AdminHistoryScreen extends ConsumerStatefulWidget {
  const _AdminHistoryScreen();

  @override
  ConsumerState<_AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends ConsumerState<_AdminHistoryScreen> {
  static const _pageSize = 50;

  final _scroll = ScrollController();
  final List<HistoryUserEntry> _items = [];
  int _count = 0;
  bool _loading = false;
  Object? _error;
  String _q = '';
  String _company = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) _loadMore();
    });
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _count = 0;
      _error = null;
    });
    await _loadMore(force: true);
  }

  Future<void> _loadMore({bool force = false}) async {
    if (_loading || (!force && _items.length >= _count)) return;
    setState(() => _loading = true);
    try {
      final page = await ref
          .read(repositoryProvider)
          .fetchHistoryUsers(
            q: _q,
            company: _company,
            limit: _pageSize,
            offset: _items.length,
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.results);
        _count = page.results.isEmpty ? _items.length : page.count;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openFilter() async {
    final result = await Navigator.of(context).push<(String, String)>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => HistoryFilterDialog(q: _q, company: _company),
      ),
    );
    if (result == null) return;
    _q = result.$1;
    _company = result.$2;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_items.isEmpty && _loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items.isEmpty && _error != null) {
      body = Center(
        child: RetryMessage(message: errorMessage(_error!), onRetry: _reload),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _reload,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(vertical: 5),
          itemCount: _items.isEmpty ? 1 : _items.length + (_loading ? 1 : 0),
          itemBuilder: (context, i) {
            if (_items.isEmpty) return const EmptyText('Aucun historique');
            if (i >= _items.length) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final entry = _items[i];
            return HistoryUserRow(
              entry: entry,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HistoryDetailsScreen(user: entry.user),
                ),
              ),
            );
          },
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Historique',
              action: IconButton(
                tooltip: 'Filtre',
                onPressed: _openFilter,
                icon: const Icon(Icons.filter_list, color: AppColors.blueGreen),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Legacy row_item_historique.xml.
class HistoryUserRow extends StatelessWidget {
  const HistoryUserRow({super.key, required this.entry, required this.onTap});

  final HistoryUserEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = entry.user;
    final last = entry.last;
    const tint = TextStyle(color: AppColors.tint, fontSize: 13);
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(5),
                    child: UserAvatar(
                      size: 65,
                      photoUrl: user.photoUrl,
                      initials: user.initials,
                      color: user.avatarColor,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            color: AppColors.gray,
                            fontSize: 16,
                          ),
                        ),
                        if (user.description.isNotEmpty)
                          Text(user.description, style: tint),
                        if (user.company.isNotEmpty) Text(user.company, style: tint),
                      ],
                    ),
                  ),
                ],
              ),
              if (last != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dernière consultation :',
                        style: TextStyle(
                          color: AppColors.gray,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(last.path, style: const TextStyle(color: AppColors.tint)),
                      Text(
                        formatHistoryLine(last.openedAt, last.durationSeconds),
                        style: const TextStyle(color: AppColors.tint),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Legacy filtre_historique_dialogue.xml. Pops `(q, company)`.
class HistoryFilterDialog extends StatefulWidget {
  const HistoryFilterDialog({super.key, this.q = '', this.company = ''});

  final String q;
  final String company;

  @override
  State<HistoryFilterDialog> createState() => _HistoryFilterDialogState();
}

class _HistoryFilterDialogState extends State<HistoryFilterDialog> {
  late final _q = TextEditingController(text: widget.q);
  late final _company = TextEditingController(text: widget.company);

  @override
  void dispose() {
    _q.dispose();
    _company.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LegacyDialogScaffold(
    title: 'Filtre',
    submitLabel: 'Appliquer le filtre',
    onSubmit: () =>
        Navigator.of(context).pop((_q.text.trim(), _company.text.trim())),
    children: [
      LegacyField(
        label: 'Utilisateur',
        child: TextField(
          controller: _q,
          style: legacyFieldTextStyle,
          decoration: legacyInputDecoration(hint: 'Prénom Nom'),
        ),
      ),
      LegacyField(
        label: 'Filiale',
        child: TextField(
          controller: _company,
          style: legacyFieldTextStyle,
          decoration: legacyInputDecoration(hint: 'Filiale'),
        ),
      ),
    ],
  );
}
