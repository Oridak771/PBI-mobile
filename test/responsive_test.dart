import 'package:cbi_mobile/core/layout/adaptive.dart';
import 'package:cbi_mobile/data/models/catalog.dart';
import 'package:cbi_mobile/data/repositories/demo_fixtures.dart';
import 'package:cbi_mobile/features/auth/login_screen.dart';
import 'package:cbi_mobile/features/history/history_screen.dart';
import 'package:cbi_mobile/features/home/home_tiles.dart';
import 'package:cbi_mobile/features/shell/shell_controller.dart';
import 'package:cbi_mobile/features/shell/shell_screen.dart';
import 'package:cbi_mobile/features/tickets/ticket_create_screen.dart';
import 'package:cbi_mobile/features/tickets/ticket_detail_screen.dart';
import 'package:cbi_mobile/features/tickets/tickets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// Small phone with large fonts, and a landscape tablet (normal and large
/// fonts). Any RenderFlex overflow fails the test.
const windows = <(String, Size, double)>[
  ('320dp x1.3', Size(320, 640), 1.3),
  ('1024x768', Size(1024, 768), 1.0),
  ('1024x768 x1.3', Size(1024, 768), 1.3),
  ('768x1024 portrait tablet', Size(768, 1024), 1.0),
];

void main() {
  test('window size classes', () {
    expect(WindowSize.of(320), WindowSize.compact);
    expect(WindowSize.of(599), WindowSize.compact);
    expect(WindowSize.of(600), WindowSize.medium);
    expect(WindowSize.of(839), WindowSize.medium);
    expect(WindowSize.of(840), WindowSize.expanded);
    expect(AdaptiveDimens.gutter(400), 16);
    expect(AdaptiveDimens.gutter(1000), 140);
    expect(AppOrientations.isTabletSize(const Size(360, 800)), isFalse);
    expect(AppOrientations.isTabletSize(const Size(1280, 800)), isTrue);
  });

  testWidgets('system text scale is clamped to 1.3', (tester) async {
    setWindowSize(tester, const Size(400, 800), textScale: 2);
    late double scale;
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) {
            scale = MediaQuery.textScalerOf(context).scale(10) / 10;
            return const SizedBox();
          },
        ),
        repo: FakeRepository(),
      ),
    );
    expect(scale, closeTo(1.3, 0.001));
  });

  for (final (label, size, scale) in windows) {
    group(label, () {
      Future<void> pump(
        WidgetTester tester,
        Widget child, {
        FakeRepository? repo,
      }) async {
        setWindowSize(tester, size, textScale: scale);
        await tester.pumpWidget(
          testApp(child, repo: repo ?? FakeRepository(), scaffold: false),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('login', (tester) async {
        await pump(tester, const LoginScreen());
        expect(find.text('CONNEXION'), findsOneWidget);
      });

      for (final tab in ShellTab.values) {
        testWidgets('shell ${tab.title}', (tester) async {
          await pump(
            tester,
            const ShellScreen(),
            repo: FakeRepository(catalog: Catalog.fromJson(demoCatalogJson())),
          );
          final container = ProviderScope.containerOf(
            tester.element(find.byType(ShellScreen)),
          );
          container.read(shellProvider.notifier).selectTab(tab);
          await tester.pumpAndSettle();
          final compact = size.width < 600;
          expect(
            find.byType(NavigationBar),
            compact ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(NavigationRail),
            compact ? findsNothing : findsOneWidget,
          );
        });
      }

      testWidgets('tickets list', (tester) async {
        await pump(tester, const TicketsScreen());
        expect(find.byKey(const ValueKey('ticket-row-5')), findsOneWidget);
      });

      testWidgets('ticket detail', (tester) async {
        await pump(tester, const TicketDetailScreen(ticketId: 4));
        expect(find.byKey(const Key('ticket-header')), findsOneWidget);
      });

      testWidgets('ticket create', (tester) async {
        await pump(tester, const TicketCreateScreen());
        expect(find.text('Nouveau ticket'), findsOneWidget);
      });

      testWidgets('history', (tester) async {
        await pump(tester, const HistoryScreen());
        expect(find.text('Historique détaillé'), findsOneWidget);
      });
    });
  }

  testWidgets('tablet home: société / pôle cards wrap, same card size', (
    tester,
  ) async {
    setWindowSize(tester, const Size(1024, 768));
    await tester.pumpWidget(
      testApp(
        const ShellScreen(),
        repo: FakeRepository(catalog: Catalog.fromJson(demoCatalogJson())),
        scaffold: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Wrap), findsWidgets);
    final cards = find.byType(GroupCard);
    expect(tester.getSize(cards.first), const Size(88, 124));
    // Several rows inside one section: more than one distinct y.
    final ys = {
      for (final e in cards.evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dy,
    };
    expect(ys.length, greaterThan(1));
  });

  testWidgets('expanded tickets: list and detail side by side', (tester) async {
    setWindowSize(tester, const Size(1280, 800));
    await tester.pumpWidget(
      testApp(const TicketsScreen(), repo: FakeRepository(), scaffold: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sélectionnez un ticket'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ticket-row-4')));
    await tester.pumpAndSettle();
    // Same route: detail in the right pane, list still visible.
    expect(find.byType(TicketDetailScreen), findsNothing);
    expect(find.byType(TicketDetailView), findsOneWidget);
    expect(find.byKey(const ValueKey('ticket-row-5')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('ticket-header'))).dx,
      greaterThan(AdaptiveDimens.listPaneWidth),
    );
  });

  testWidgets('compact tickets: a row opens the detail screen', (tester) async {
    setWindowSize(tester, const Size(400, 800));
    await tester.pumpWidget(
      testApp(const TicketsScreen(), repo: FakeRepository(), scaffold: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ticket-row-4')));
    await tester.pumpAndSettle();
    expect(find.byType(TicketDetailScreen), findsOneWidget);
    expect(find.text('Ticket #4'), findsOneWidget);
  });

  testWidgets('expanded settings: groups in two columns', (tester) async {
    setWindowSize(tester, const Size(1280, 800));
    await tester.pumpWidget(
      testApp(const ShellScreen(), repo: FakeRepository(), scaffold: false),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ShellScreen)),
    );
    container.read(shellProvider.notifier).selectTab(ShellTab.settings);
    await tester.pumpAndSettle();
    final activity = tester.getTopLeft(find.text('ACTIVITÉ'));
    final appearance = tester.getTopLeft(find.text('APPARENCE'));
    expect(appearance.dx, greaterThan(activity.dx + 200));
    expect((appearance.dy - activity.dy).abs(), lessThan(4));
  });
}
