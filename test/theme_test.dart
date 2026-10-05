import 'package:cbi_mobile/core/theme/app_palette.dart';
import 'package:cbi_mobile/core/theme/app_theme.dart';
import 'package:cbi_mobile/core/theme/theme_mode_controller.dart';
import 'package:cbi_mobile/features/settings/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_app.dart';

void main() {
  group('palette', () {
    test('dark tokens match the approved glass mockup', () {
      const p = AppPalette.dark;
      expect(p.background, const Color(0xFF0C0E11));
      expect(p.backgroundTop, const Color(0xFF121519));
      expect(p.text, const Color(0xFFF5F6F8));
      // rgba(235,238,243,.62)
      expect(p.textMuted, const Color(0x9EEBEEF3));
      expect(p.primary, const Color(0xFFA5CF4B));
      expect(p.onPrimary, const Color(0xFF10140A));
      expect(p.primaryText, const Color(0xFFB9E06A));
      expect(p.primaryBright, const Color(0xFFC8EA82));
      expect(p.success, const Color(0xFF8EE0B0));
      // Glass: white 14% -> 4%, white 16% border, white 28% highlight.
      expect(p.glassTop, const Color(0x24FFFFFF));
      expect(p.glassBottom, const Color(0x0AFFFFFF));
      expect(p.glassBorder, const Color(0x29FFFFFF));
      expect(p.glassHighlight, const Color(0x47FFFFFF));
      // Glows: green .55, teal .40, blue .32.
      expect(p.glowGreen, const Color(0x8CA5CF4B));
      expect(p.glowTeal, const Color(0x6626A69A));
      expect(p.glowBlue, const Color(0x527CC4E8));
      expect(p.gradientTop, const Color(0xFFB6DD62));
      expect(p.gradientBottom, const Color(0xFF93BF3A));
    });

    test('light tokens: same glass language on a pale background', () {
      const p = AppPalette.light;
      expect(p.background, const Color(0xFFF3F5F8));
      expect(p.text, const Color(0xFF1B1E24));
      expect(p.textMuted, const Color(0xFF5F6168));
      expect(p.primary, const Color(0xFFA5CF4B));
      expect(p.primaryText, const Color(0xFF5E8A1F));
      // White 60-70% frosted glass, glows at a lower alpha than in dark.
      expect(p.glassTop.a, inInclusiveRange(0.6, 0.75));
      expect(p.glassBottom.a, inInclusiveRange(0.55, 0.7));
      expect(p.glowGreen.a, lessThan(AppPalette.dark.glowGreen.a));
      expect(p.glowTeal.a, lessThan(AppPalette.dark.glowTeal.a));
      expect(p.glowBlue.a, lessThan(AppPalette.dark.glowBlue.a));
    });

    test('themes carry their palette and the glass style', () {
      for (final brightness in Brightness.values) {
        final theme = buildAppTheme(brightness);
        final palette = theme.extension<AppPalette>()!;
        expect(palette.brightness, brightness);
        expect(theme.brightness, brightness);
        expect(theme.scaffoldBackgroundColor, palette.background);
        expect(theme.colorScheme.primary, palette.primary);
        expect(theme.cardTheme.elevation, 0);
        expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
        expect(theme.navigationBarTheme.backgroundColor, Colors.transparent);
        expect(theme.tabBarTheme.indicatorColor, palette.primary);
        expect(theme.tabBarTheme.labelColor, palette.primaryText);
        expect(theme.tabBarTheme.unselectedLabelColor, palette.textMuted);
        // Roboto = the Material / Android default: nothing bundled.
        expect(theme.textTheme.bodyMedium?.fontFamily, isNot('Poppins'));
      }
    });
  });

  group('theme mode persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('follows the phone by default', () async {
      expect(await const PrefsThemeModeStore().load(), ThemeMode.system);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('shared_preferences store round-trips every mode', () async {
      const store = PrefsThemeModeStore();
      for (final mode in ThemeMode.values) {
        await store.save(mode);
        expect(await store.load(), mode);
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PrefsThemeModeStore.key), 'dark');
      expect(PrefsThemeModeStore.parse('garbage'), ThemeMode.system);
    });

    test('controller persists the choice, restored on the next start', () async {
      final store = MemoryThemeModeStore();
      final first = ProviderContainer(
        overrides: [themeModeStoreProvider.overrideWithValue(store)],
      );
      await first.read(themeModeProvider.notifier).set(ThemeMode.dark);
      expect(first.read(themeModeProvider), ThemeMode.dark);
      expect(store.mode, ThemeMode.dark);
      first.dispose();

      // main.dart loads the stored mode before runApp.
      final restored = ProviderContainer(
        overrides: [
          themeModeStoreProvider.overrideWithValue(store),
          initialThemeModeProvider.overrideWithValue(await store.load()),
        ],
      );
      addTearDown(restored.dispose);
      expect(restored.read(themeModeProvider), ThemeMode.dark);
    });
  });

  testWidgets('Apparence switches the theme instantly and persists it', (
    tester,
  ) async {
    final store = MemoryThemeModeStore();
    await tester.pumpWidget(
      testApp(const SettingsView(), repo: FakeRepository(), themeStore: store),
    );
    await tester.pumpAndSettle();

    Brightness brightness() =>
        Theme.of(tester.element(find.byType(SettingsView))).brightness;
    // Platform brightness is light in tests; "Système" follows it.
    expect(brightness(), Brightness.light);
    for (final label in ['Système', 'Clair', 'Sombre']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    expect(store.mode, ThemeMode.dark);

    await tester.tap(find.text('Clair'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light);
    expect(store.mode, ThemeMode.light);

    await tester.tap(find.text('Système'));
    await tester.pumpAndSettle();
    expect(store.mode, ThemeMode.system);

    // Logout is a danger outlined button (below the Sécurité section).
    await tester.scrollUntilVisible(
      find.byKey(const Key('logout-button')),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    final logout = tester.widget<OutlinedButton>(
      find.byKey(const Key('logout-button')),
    );
    expect(logout, isNotNull);
    expect(find.text('Se déconnecter'), findsOneWidget);
  });
}
