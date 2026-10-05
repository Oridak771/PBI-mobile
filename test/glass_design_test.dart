import 'package:cbi_mobile/core/utils/formatters.dart';
import 'package:cbi_mobile/core/widgets/common.dart';
import 'package:cbi_mobile/core/widgets/glass.dart';
import 'package:cbi_mobile/core/widgets/report_tile.dart';
import 'package:cbi_mobile/data/models/catalog.dart';
import 'package:cbi_mobile/data/repositories/demo_fixtures.dart';
import 'package:cbi_mobile/features/reports/report_list.dart';
import 'package:cbi_mobile/features/shell/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  final now = DateTime(2026, 10, 5, 12);

  test('report meta line: Vue mobile, code, modification date', () {
    Report r({bool mobile = false, PhoneEdition? phone, DateTime? modified}) =>
        Report(
          id: 1,
          name: 'R',
          hasMobileLayout: mobile,
          phone: phone,
          modifiedAt: modified,
        );
    expect(reportMeta(r(mobile: true), 'DCO', now: now), (
      mobile: true,
      text: 'Vue mobile · DCO',
    ));
    expect(
      reportMeta(
        r(phone: const PhoneEdition(id: 2, embedUrl: 'x')),
        'DG',
        now: now,
      ).text,
      'Vue mobile · DG',
    );
    expect(reportMeta(r(), 'DAA', now: now), (mobile: false, text: 'DAA'));
    expect(
      reportMeta(
        r(modified: now.subtract(const Duration(days: 1))),
        'DFC',
        now: now,
      ).text,
      'DFC · mis à jour hier',
    );
    expect(
      reportMeta(
        r(modified: now.subtract(const Duration(hours: 3))),
        'DFC',
        now: now,
      ).text,
      'DFC · mis à jour il y a 3 h',
    );
    expect(locationLabel('Consolidé / DFC'), 'DFC');
    expect(locationLabel(''), '');
  });

  test('relative times of the glass lists', () {
    expect(relativeShortFr(now.subtract(const Duration(minutes: 3)), now: now), '3 min');
    expect(relativeShortFr(now.subtract(const Duration(hours: 2)), now: now), '2 h');
    expect(relativeShortFr(now.subtract(const Duration(days: 1)), now: now), 'hier');
    expect(relativeShortFr(now.subtract(const Duration(days: 2)), now: now), '2 j');
    expect(relativeAgoFr(now.subtract(const Duration(hours: 2)), now: now), 'il y a 2 h');
    expect(relativeAgoFr(now.subtract(const Duration(days: 1)), now: now), 'hier');
    expect(relativeShortFr(null), '');
  });

  test('report icon tiles are deterministic, from a small business set', () {
    final a = ReportVisual.of('Situation Financière');
    final b = ReportVisual.of('Situation Financière');
    expect(a.icon, b.icon);
    expect(a.tint, b.tint);
    expect(ReportVisual.icons, contains(a.icon));
    expect(ReportVisual.of('Achats et approvisionnement').icon,
        Icons.local_shipping_outlined);
    expect(ReportVisual.of('Créances clients').icon, Icons.receipt_long_outlined);
    expect(ReportVisual.of('Marges par produits').icon, Icons.show_chart_rounded);
    expect(ReportVisual.stableHash('abc'), ReportVisual.stableHash('abc'));
    // The three tints are all used across the demo catalog.
    final tints = {
      for (final r in Catalog.fromJson(demoCatalogJson()).reports.values)
        ReportVisual.of(r.name).tint,
    };
    expect(tints, TileTint.values.toSet());
  });

  testWidgets('blur only on static chrome: list cards have no BackdropFilter', (
    tester,
  ) async {
    setWindowSize(tester, const Size(412, 892));
    await tester.pumpWidget(
      testApp(
        const ShellScreen(),
        repo: FakeRepository(catalog: Catalog.fromJson(demoCatalogJson())),
        scaffold: false,
        themeMode: ThemeMode.dark,
      ),
    );
    await tester.pumpAndSettle();
    // Blurred: tab bar, search field, section chip bar, bell.
    for (final key in ['glass-tab-bar', 'home-search', 'home-sections']) {
      expect(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
        reason: key,
      );
    }
    // Not blurred: cards inside the scrolling lists / grids.
    expect(
      find.descendant(
        of: find.byType(AppCard),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
    // Each blurred surface sits behind its own repaint boundary.
    for (final e in find.byType(BackdropFilter).evaluate()) {
      expect(
        find.ancestor(
          of: find.byWidget(e.widget),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    }
    expect(find.byType(GlassBackground), findsOneWidget);
  });

  testWidgets('segmented bar works in a Row (viewer toolbar on tablets)', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      testApp(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassSegmentedBar<String>(
              expand: true,
              segments: const [
                GlassSegment('m', 'Mobile', icon: Icons.smartphone_rounded),
                GlassSegment('d', 'Bureau'),
              ],
              selected: const {'m'},
              onChanged: (v) => picked = v,
            ),
          ],
        ),
        repo: FakeRepository(),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Bureau'));
    expect(picked, 'd');
  });

  testWidgets('primary button: green gradient, dark label', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        Center(child: GradientButton(label: 'Go', onPressed: () => taps++)),
        repo: FakeRepository(),
        themeMode: ThemeMode.dark,
      ),
    );
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(GradientButton),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final gradient = (box.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.colors, const [Color(0xFFB6DD62), Color(0xFF93BF3A)]);
    expect(
      tester.widget<Text>(find.text('Go')).style?.color,
      const Color(0xFF10140A),
    );
    await tester.tap(find.byType(GradientButton));
    expect(taps, 1);
  });
}
