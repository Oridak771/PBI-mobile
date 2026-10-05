import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/adaptive.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/report_tile.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/catalog.dart';
import '../reports/catalog_controller.dart';
import '../reports/report_list.dart';

/// Reports of [catalog] whose name or location contains every word of
/// [query] (case and accent insensitive), sorted by name. Empty query → [].
List<Report> searchReports(Catalog catalog, String query) {
  final words = foldAccents(query.toLowerCase())
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return const [];
  final matches = [
    for (final r in catalog.reports.values)
      if (_matches(r, words)) r,
  ]..sort((a, b) => foldAccents(a.name.toLowerCase())
        .compareTo(foldAccents(b.name.toLowerCase())));
  return matches;
}

bool _matches(Report report, List<String> words) {
  final text = foldAccents('${report.name} ${report.location}'.toLowerCase());
  return words.every(text.contains);
}

/// "Rechercher un rapport": instant local search over the whole catalog.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final catalog = ref.watch(catalogProvider).value;
    final query = _query.text;
    final results = catalog == null
        ? const <Report>[]
        : searchReports(catalog, query);

    final Widget body;
    if (catalog == null) {
      body = const SkeletonList();
    } else if (query.trim().isEmpty) {
      body = const Center(
        child: EmptyText(
          "Saisissez le nom ou l'emplacement d'un rapport",
          icon: Icons.search_rounded,
        ),
      );
    } else if (results.isEmpty) {
      body = const Center(
        child: EmptyText('Aucun rapport trouvé', icon: Icons.search_off_rounded),
      );
    } else {
      body = CenteredContent(
        builder: (context, gutter) => ListView(
          key: const Key('search-results'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 24),
          children: [
            SectionHeader(
              'Résultats',
              count: results.length,
              padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
            ),
            ReportListPanel(
              entries: [for (final r in results) (r, r.location)],
            ),
          ],
        ),
      );
    }

    return GlassScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CenteredContent(
              builder: (context, gutter) => Padding(
                padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 8),
                child: Row(
                  children: [
                    GlassIconButton(
                      tooltip: 'Retour',
                      size: 40,
                      icon: Icons.chevron_left_rounded,
                      iconSize: 24,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassPanel(
                        blur: true,
                        borderRadius: BorderRadius.circular(22),
                        child: SizedBox(
                          height: 44,
                          child: TextField(
                            key: const Key('search-input'),
                            controller: _query,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(color: palette.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              hintText: 'Rechercher un rapport',
                              hintStyle: TextStyle(
                                color: palette.textMuted,
                                fontSize: 12.5,
                              ),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                size: 18,
                                color: palette.textMuted,
                              ),
                              suffixIcon: query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Effacer',
                                      onPressed: () =>
                                          setState(_query.clear),
                                      icon: Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: palette.textMuted,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: body),
            const SizedBox(height: AppDimens.page / 2),
          ],
        ),
      ),
    );
  }
}
