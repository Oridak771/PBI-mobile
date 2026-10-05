import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';

/// Tint of a report icon tile.
enum TileTint { green, blue, amber }

/// Icon + tint of a report, picked deterministically from its name: a few
/// business keywords first, then a stable hash (FNV-1a, same result on every
/// run and device).
class ReportVisual {
  const ReportVisual(this.icon, this.tint);

  final IconData icon;
  final TileTint tint;

  static const icons = <IconData>[
    Icons.bar_chart_rounded,
    Icons.pie_chart_outline_rounded,
    Icons.show_chart_rounded,
    Icons.receipt_long_outlined,
    Icons.local_shipping_outlined,
    Icons.people_outline_rounded,
    Icons.map_outlined,
  ];

  static const _keywords = <(String, IconData)>[
    ('achat', Icons.local_shipping_outlined),
    ('approvision', Icons.local_shipping_outlined),
    ('stock', Icons.local_shipping_outlined),
    ('livraison', Icons.local_shipping_outlined),
    ('creance', Icons.receipt_long_outlined),
    ('factur', Icons.receipt_long_outlined),
    ('balance', Icons.receipt_long_outlined),
    ('effectif', Icons.people_outline_rounded),
    ('salari', Icons.people_outline_rounded),
    ('absent', Icons.people_outline_rounded),
    ('rh', Icons.people_outline_rounded),
    ('region', Icons.map_outlined),
    ('carte', Icons.map_outlined),
    ('marge', Icons.show_chart_rounded),
    ('evolution', Icons.show_chart_rounded),
    ('tendance', Icons.show_chart_rounded),
    ('encaissement', Icons.pie_chart_outline_rounded),
    ('repartition', Icons.pie_chart_outline_rounded),
    ('chiffre', Icons.bar_chart_rounded),
    ('vente', Icons.bar_chart_rounded),
  ];

  /// 32-bit FNV-1a of [text].
  static int stableHash(String text) {
    var h = 0x811c9dc5;
    for (final unit in text.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  static ReportVisual of(String name) {
    final key = foldAccents(name.toLowerCase());
    final h = stableHash(key);
    final tint = TileTint.values[h % TileTint.values.length];
    for (final (word, icon) in _keywords) {
      final match = word.length <= 2
          ? RegExp('\\b$word\\b').hasMatch(key)
          : key.contains(word);
      if (match) return ReportVisual(icon, tint);
    }
    return ReportVisual(icons[(h ~/ 3) % icons.length], tint);
  }
}

/// Lower-case-insensitive comparison helper: removes French accents.
String foldAccents(String text) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyy';
  final buffer = StringBuffer();
  for (final ch in text.split('')) {
    final i = from.indexOf(ch);
    if (i < 0) {
      buffer.write(ch);
    } else if (ch == 'œ') {
      buffer.write('oe');
    } else if (ch == 'æ') {
      buffer.write('ae');
    } else {
      buffer.write(to[i]);
    }
  }
  return buffer.toString();
}

/// Background / icon colours of a tile tint (22% alpha backgrounds).
({Color bg, Color fg}) tileColors(AppPalette palette, TileTint tint) =>
    switch (tint) {
      TileTint.green => (
        bg: palette.primary.withValues(alpha: 0.22),
        fg: palette.primaryText,
      ),
      TileTint.blue => (
        bg: const Color(0xFF7CC4E8).withValues(alpha: palette.isDark ? 0.22 : 0.28),
        fg: palette.tileBlue,
      ),
      TileTint.amber => (
        bg: const Color(0xFFE8B86A).withValues(alpha: palette.isDark ? 0.22 : 0.28),
        fg: palette.tileAmber,
      ),
    };

/// 40×40 tinted tile (radius 13) with an icon.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.tint = TileTint.green,
    this.size = AppDimens.tile,
  });

  final IconData icon;
  final TileTint tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = tileColors(context.palette, tint);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(size * AppDimens.radiusTile / 40),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 19 / 40, color: colors.fg),
    );
  }
}

/// Icon tile of a report (icon and tint from its name).
class ReportIconTile extends StatelessWidget {
  const ReportIconTile({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final visual = ReportVisual.of(name);
    return IconTile(
      key: const Key('report-icon-tile'),
      icon: visual.icon,
      tint: visual.tint,
      size: size,
    );
  }
}
