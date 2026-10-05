import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/layout/adaptive.dart';
import 'core/theme/theme_mode_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Phones: portrait, like the legacy app (the viewer unlocks rotation).
  // Tablets: every orientation on every screen.
  await AppOrientations.init();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Read the "Apparence" choice first: the first frame uses the right theme.
  final themeMode = await const PrefsThemeModeStore().load();
  runApp(
    ProviderScope(
      retry: providerRetry,
      overrides: [initialThemeModeProvider.overrideWithValue(themeMode)],
      child: const CbiApp(),
    ),
  );
}
