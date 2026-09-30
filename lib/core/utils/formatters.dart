/// Version and date helpers.
library;

/// Compares dotted versions (`2.2` < `3.0.0` < `3.0.1`). Non-numeric suffixes
/// (`3.0.0+7`, `3.0.0-beta`) are ignored.
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .split(RegExp(r'[+\-]'))
      .first
      .split('.')
      .map((p) => int.tryParse(p.trim()) ?? 0)
      .toList();
  final x = parse(a), y = parse(b);
  for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
    final l = i < x.length ? x[i] : 0, r = i < y.length ? y[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

bool isVersionLower(String current, String minimum) =>
    compareVersions(current, minimum) < 0;

String _two(int v) => v.toString().padLeft(2, '0');

/// `dd/MM/yyyy`.
String formatDate(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${_two(l.day)}/${_two(l.month)}/${l.year}';
}

/// `HH:mm`.
String formatTime(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}';
}

/// `HH:mm:ss` for a duration in seconds.
String formatDuration(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${_two(s ~/ 3600)}:${_two((s % 3600) ~/ 60)}:${_two(s % 60)}';
}

/// Legacy history line: `dd/MM/yyyy  HH:mm   HH:mm:ss`.
String formatHistoryLine(DateTime? openedAt, int durationSeconds) =>
    '${formatDate(openedAt)}  ${formatTime(openedAt)}   '
    '${formatDuration(durationSeconds)}';

/// Abbreviated French relative time: `3mn`, `2h`, `1j`, `2mois`, `1an`.
String relativeTimeFr(DateTime? date, {DateTime? now}) {
  if (date == null) return '';
  final diff = (now ?? DateTime.now()).difference(date);
  if (diff.inMinutes < 1) return '1mn';
  if (diff.inHours < 1) return '${diff.inMinutes}mn';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 30) return '${diff.inDays}j';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30}mois';
  return '${diff.inDays ~/ 365}an';
}
