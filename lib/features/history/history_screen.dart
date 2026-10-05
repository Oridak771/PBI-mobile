import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/layout/adaptive.dart';
import '../../core/providers.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/history.dart';
import '../auth/session_controller.dart';
import 'history_details_screen.dart';
import '../../core/widgets/glass.dart';

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
    final result = await showHistoryFilterSheet(
      context,
      q: _q,
      company: _company,
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
      body = const SkeletonList(count: 8, lines: 3);
    } else if (_items.isEmpty && _error != null) {
      body = Center(
        child: RetryMessage(message: errorMessage(_error!), onRetry: _reload),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _reload,
        child: CenteredContent(
          builder: (context, gutter) => ListView.builder(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 24),
          itemCount: _items.isEmpty ? 1 : _items.length + (_loading ? 1 : 0),
          itemBuilder: (context, i) {
            if (_items.isEmpty) {
              return const EmptyText(
                'Aucun historique',
                icon: Icons.history_rounded,
              );
            }
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
        ),
      );
    }
    final palette = context.palette;
    final filtered = _q.isNotEmpty || _company.isNotEmpty;
    return GlassScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: 'Historique',
              action: GlassIconButton(
                tooltip: 'Filtre',
                size: 40,
                onPressed: _openFilter,
                icon: Icons.filter_list_rounded,
                color: filtered ? palette.primaryText : palette.text,
                badge: filtered ? GlowDot(color: palette.primaryText) : null,
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// User with their last consultation (admin history list).
class HistoryUserRow extends StatelessWidget {
  const HistoryUserRow({super.key, required this.entry, required this.onTap});

  final HistoryUserEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final user = entry.user;
    final last = entry.last;
    final muted = TextStyle(color: palette.textMuted, fontSize: 13);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                size: 48,
                photoUrl: user.photoUrl,
                initials: user.initials,
                color: user.avatarColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (user.description.isNotEmpty)
                      Text(user.description, style: muted),
                    if (user.company.isNotEmpty) Text(user.company, style: muted),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textSubtle),
            ],
          ),
          if (last != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.glassSelected,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dernière consultation :',
                    style: TextStyle(
                      color: palette.textSubtle,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    last.path,
                    style: TextStyle(color: palette.text, fontSize: 13),
                  ),
                  Text(
                    formatHistoryLine(last.openedAt, last.durationSeconds),
                    style: muted,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// History filter bottom sheet. Returns `(q, company)`, `null` when closed.
Future<(String, String)?> showHistoryFilterSheet(
  BuildContext context, {
  String q = '',
  String company = '',
}) => showGlassSheet<(String, String)>(
  context: context,
  isScrollControlled: true,
  builder: (_) => HistoryFilterSheet(q: q, company: company),
);

class HistoryFilterSheet extends StatefulWidget {
  const HistoryFilterSheet({super.key, this.q = '', this.company = ''});

  final String q;
  final String company;

  @override
  State<HistoryFilterSheet> createState() => _HistoryFilterSheetState();
}

class _HistoryFilterSheetState extends State<HistoryFilterSheet> {
  late final _q = TextEditingController(text: widget.q);
  late final _company = TextEditingController(text: widget.company);

  @override
  void dispose() {
    _q.dispose();
    _company.dispose();
    super.dispose();
  }

  void _apply() =>
      Navigator.of(context).pop((_q.text.trim(), _company.text.trim()));

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.page,
            0,
            AppDimens.page,
            AppDimens.page,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Filtre',
                style: TextStyle(
                  color: palette.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Utilisateur',
                child: TextField(
                  controller: _q,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Prénom Nom',
                    prefixIcon: Icon(Icons.person_search_rounded),
                  ),
                ),
              ),
              LabeledField(
                label: 'Filiale',
                child: TextField(
                  controller: _company,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _apply(),
                  decoration: const InputDecoration(
                    hintText: 'Filiale',
                    prefixIcon: Icon(Icons.apartment_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SubmitButton(label: 'Appliquer le filtre', onPressed: _apply),
            ],
          ),
        ),
      ),
    );
  }
}
