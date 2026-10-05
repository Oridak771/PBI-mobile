import 'package:cbi_mobile/app.dart';
import 'package:cbi_mobile/core/images/logo_images.dart';
import 'package:cbi_mobile/core/providers.dart';
import 'package:cbi_mobile/core/security/biometric_auth.dart';
import 'package:cbi_mobile/core/storage/lock_settings_store.dart';
import 'package:cbi_mobile/core/storage/remembered_credentials_store.dart';
import 'package:cbi_mobile/core/storage/session_store.dart';
import 'package:cbi_mobile/core/theme/theme_mode_controller.dart';
import 'package:cbi_mobile/data/models/user.dart';
import 'package:cbi_mobile/features/auth/login_screen.dart';
import 'package:cbi_mobile/features/lock/app_lock_controller.dart';
import 'package:cbi_mobile/features/lock/lock_screen.dart';
import 'package:cbi_mobile/features/shell/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  late DateTime now;
  late FakeBiometricAuth biometrics;
  late MemoryLockSettingsStore lockStore;
  late MemorySessionStore store;
  late MemoryRememberedCredentialsStore remembered;

  setUp(() {
    now = DateTime(2026, 9, 30, 9);
    biometrics = FakeBiometricAuth();
    lockStore = MemoryLockSettingsStore(const LockSettings(enabled: true));
    store = MemorySessionStore(
      session: const StoredSession(
        token: 'demo-token',
        user: User(
          id: 42,
          username: 'demo',
          name: 'Utilisateur Démo',
          initials: 'UD',
        ),
      ),
    );
    remembered = MemoryRememberedCredentialsStore(
      const RememberedCredentials(username: 'demo', password: 'pw'),
    );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          repositoryProvider.overrideWithValue(FakeRepository()),
          sessionStoreProvider.overrideWithValue(store),
          rememberedCredentialsStoreProvider.overrideWithValue(remembered),
          lockSettingsStoreProvider.overrideWithValue(lockStore),
          biometricAuthProvider.overrideWithValue(biometrics),
          clockProvider.overrideWithValue(() => now),
          appVersionProvider.overrideWith((ref) => '3.2.0'),
          initialThemeModeProvider.overrideWithValue(ThemeMode.system),
          themeModeStoreProvider.overrideWithValue(MemoryThemeModeStore()),
          logoImageResolverProvider.overrideWithValue((_) => null),
        ],
        child: const CbiApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> background(WidgetTester tester, Duration away) async {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    now = now.add(away);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
  }

  final lockScreen = find.byType(LockScreen);

  testWidgets('cold start: lock screen, back blocked, unlock → shell', (
    tester,
  ) async {
    biometrics.succeed = false; // the automatic prompt is cancelled
    await pumpApp(tester);

    expect(lockScreen, findsOneWidget);
    expect(find.text('Application verrouillée'), findsOneWidget);
    expect(find.text('Utilisateur Démo'), findsOneWidget);
    expect(find.text('UD'), findsOneWidget);
    expect(find.text('Déverrouiller'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);
    expect(biometrics.reasons, [LockPrompts.unlock]);
    expect(find.byType(ShellScreen), findsNothing);

    // Android back: swallowed while locked.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(lockScreen, findsOneWidget);

    biometrics.succeed = true;
    await tester.tap(find.byKey(const Key('lock-unlock')));
    await tester.pumpAndSettle();
    expect(lockScreen, findsNothing);
    expect(find.byType(ShellScreen), findsOneWidget);
  });

  testWidgets('cold start: the prompt opens by itself', (tester) async {
    await pumpApp(tester);
    expect(biometrics.reasons, [LockPrompts.unlock]);
    expect(lockScreen, findsNothing);
    expect(find.byType(ShellScreen), findsOneWidget);
  });

  testWidgets('no lock when disabled or without a session', (tester) async {
    lockStore.settings = const LockSettings();
    await pumpApp(tester);
    expect(lockScreen, findsNothing);
    expect(biometrics.reasons, isEmpty);
    await background(tester, const Duration(hours: 1));
    expect(lockScreen, findsNothing);
  });

  testWidgets('resume: locks after the delay, keeps the screen underneath', (
    tester,
  ) async {
    await pumpApp(tester); // unlocked by the automatic prompt
    expect(find.byType(ShellScreen), findsOneWidget);

    // A secondary screen is open when the app goes to the background.
    appNavigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Détail rapport')),
      ),
    );
    await tester.pumpAndSettle();

    await background(tester, const Duration(seconds: 30)); // < 1 min
    expect(lockScreen, findsNothing);

    biometrics.succeed = false;
    await background(tester, const Duration(minutes: 1));
    expect(lockScreen, findsOneWidget);
    // Still mounted underneath (state preserved), just covered.
    expect(find.text('Détail rapport', skipOffstage: false), findsOneWidget);

    // Back does not pop the screen under the lock.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(lockScreen, findsOneWidget);

    biometrics.succeed = true;
    await tester.tap(find.byKey(const Key('lock-unlock')));
    await tester.pumpAndSettle();
    expect(lockScreen, findsNothing);
    expect(find.text('Détail rapport'), findsOneWidget);
  });

  testWidgets('"Immédiat" locks after any trip to the background', (
    tester,
  ) async {
    lockStore.settings = const LockSettings(
      enabled: true,
      delay: LockDelay.immediate,
    );
    await pumpApp(tester);
    biometrics.succeed = false;
    await background(tester, Duration.zero);
    expect(lockScreen, findsOneWidget);
  });

  testWidgets('a prompt / notification shade (inactive only) never locks', (
    tester,
  ) async {
    lockStore.settings = const LockSettings(
      enabled: true,
      delay: LockDelay.immediate,
    );
    await pumpApp(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    now = now.add(const Duration(minutes: 20));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(lockScreen, findsNothing);
  });

  testWidgets('cancelled prompt does not reopen by itself (only on a real resume)', (
    tester,
  ) async {
    biometrics.succeed = false;
    await pumpApp(tester);
    expect(biometrics.reasons, hasLength(1));
    // The prompt closing = inactive → resumed: no new prompt.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(biometrics.reasons, hasLength(1));
    // Back from the home screen: prompt again.
    await background(tester, const Duration(seconds: 5));
    expect(biometrics.reasons, hasLength(2));
    expect(lockScreen, findsOneWidget);
  });

  testWidgets('fingerprint and PIN removed since: never locked out', (
    tester,
  ) async {
    biometrics.current = BiometricStatus.unavailable;
    await pumpApp(tester);
    expect(lockScreen, findsNothing);
    expect(find.byType(ShellScreen), findsOneWidget);
    expect(lockStore.settings.enabled, isFalse);
  });

  testWidgets('"Se déconnecter" on the lock screen → login, credentials kept', (
    tester,
  ) async {
    biometrics.succeed = false;
    await pumpApp(tester);
    expect(lockScreen, findsOneWidget);

    await tester.tap(find.byKey(const Key('lock-logout')));
    await tester.pumpAndSettle();
    expect(find.text('Voulez-vous vraiment vous déconnecter?'), findsOneWidget);
    // Back closes the dialog, not the lock.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Voulez-vous vraiment vous déconnecter?'), findsNothing);
    expect(lockScreen, findsOneWidget);

    await tester.tap(find.byKey(const Key('lock-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Se déconnecter'));
    await tester.pumpAndSettle();

    expect(lockScreen, findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(await store.read(), isNull);
    expect((await remembered.read())?.password, 'pw');
    expect(lockStore.settings.enabled, isTrue);
  });
}
