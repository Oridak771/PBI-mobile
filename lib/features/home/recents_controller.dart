import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/catalog.dart';
import '../../data/models/history.dart';

/// `GET history/` (own consultations, last 30 days) for the "Récents" row.
final myHistoryProvider = FutureProvider<List<HistoryItem>>(
  (ref) => ref.watch(repositoryProvider).fetchMyHistory(),
);

/// A recent report of the home "Récents" row.
class RecentReport {
  const RecentReport(this.report, this.item);

  final Report report;
  final HistoryItem item;
}

/// Up to [max] distinct reports of [history] (most recent first) that are
/// still in [catalog] (reports the user lost access to are skipped).
List<RecentReport> recentReports(
  List<HistoryItem> history,
  Catalog catalog, {
  int max = 6,
}) {
  final sorted = [...history]
    ..sort((a, b) {
      final x = a.openedAt, y = b.openedAt;
      if (x == null || y == null) {
        return x == y ? 0 : (x == null ? 1 : -1);
      }
      return y.compareTo(x);
    });
  final seen = <int>{};
  final result = <RecentReport>[];
  for (final item in sorted) {
    final report = catalog.reports[item.reportId];
    if (report == null || !seen.add(item.reportId)) continue;
    result.add(RecentReport(report, item));
    if (result.length == max) break;
  }
  return result;
}
