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
    test('dark tokens match the PBI web platform', () {
      const p = AppPalette.dark;
      expect(p.background, const Color(0xFF111318));
      expect(p.surface, const Color(0xFF1C1D22));
      expect(p.surfaceAlt, const Color(0xFF25262D));
      expect(p.border, const Color(0xFF34353D));
      expect(p.text, const Color(0xFFF1F2F4));
      expect(p.textMuted, const Color(0xFFA8ABB4));
      expect(p.textSubtle, const Color(0xFF8F9097));
      expect(p.primary, const Color(0xFFA5CF4B));
      expect(p.onPrimary, const Color(0xFF1C1D22));
      expect(p.primaryText, const Color(0xFFA5CF4B));
      expect(p.danger, const Color(0xFFEF4444));
      expect(p.success, const Color(0xFF42B883));
    });

    test('light tokens match the PBI web platform', () {
      const p = AppPalette.light;
      expect(p.background, const Color(0xFFF5F5F5));
      expect(p.surface, const Color(0xFFFFFFFF));
      expect(p.surfaceAlt, const Color(0xFFF1F2F4));
      expect(p.border, const Color(0xFFE4E4E6));
      expect(p.text, const Color(0xFF2A2B30));
      expect(p.textMuted, const Color(0xFF5F6168));
      expect(p.textSubtle, const Color(0xFF8F9097));
      expect(p.primary, const Color(0xFFA5CF4B));
      expect(p.onPrimary, const Color(0xFF1C1D22));
      expect(p.primaryText, const Color(0xFF71952B));
      expect(p.danger, const Color(0xFFDC2626));
      expect(p.success, const Color(0xFF16A34A));
    });

    test('themes carry their palette and the flat web style', () {
      for (final brightness in Brightness.values) {
        final theme = buildAppTheme(brightness);
        final palette = theme.extension<AppPalette>()!;
        expect(palette.brightness, brightness);
        expect(theme.brightness, brightness);
        expect(theme.scaffoldBackgroundColor, palette.background);
        expect(theme.colorScheme.primary, palette.primary);
        expect(theme.cardTheme.elevation, 0);
        expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
        expect(theme.navigationBarTheme.backgroundColor, palette.surface);
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
    await tester.scrollUntilVisible(find.byKey(const Key('logout-button')), 200);
    final logout = tester.widget<OutlinedButton>(
      find.byKey(const Key('logout-button')),
    );
    expect(logout, isNotNull);
    expect(find.text('Se déconnecter'), findsOneWidget);
  });
}
