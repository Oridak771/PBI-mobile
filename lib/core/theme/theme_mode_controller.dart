import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence of the "Apparence" setting (Système / Clair / Sombre).
abstract class ThemeModeStore {
  Future<ThemeMode> load();
  Future<void> save(ThemeMode mode);
}

/// `shared_preferences` key `theme_mode` = `system` | `light` | `dark`.
class PrefsThemeModeStore implements ThemeModeStore {
  const PrefsThemeModeStore();

  static const key = 'theme_mode';

  static ThemeMode parse(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  @override
  Future<ThemeMode> load() async {
    try {
      return parse((await SharedPreferences.getInstance()).getString(key));
    } catch (_) {
      return ThemeMode.system;
    }
  }

  @override
  Future<void> save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, mode.name);
  }
}

class MemoryThemeModeStore implements ThemeModeStore {
  MemoryThemeModeStore([this.mode = ThemeMode.system]);

  ThemeMode mode;

  @override
  Future<ThemeMode> load() async => mode;

  @override
  Future<void> save(ThemeMode mode) async => this.mode = mode;
}

final themeModeStoreProvider = Provider<ThemeModeStore>(
  (ref) => const PrefsThemeModeStore(),
);

/// Theme mode read before `runApp` (see `main.dart`) so the first frame is
/// already in the right theme. Defaults to following the phone.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

/// Current [ThemeMode]; changes apply instantly and are persisted.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(initialThemeModeProvider);

  Future<void> set(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    try {
      await ref.read(themeModeStoreProvider).save(mode);
    } catch (_) {
      // Best effort: the choice still applies for this run.
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
