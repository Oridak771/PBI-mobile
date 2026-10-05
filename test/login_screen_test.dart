import 'package:cbi_mobile/core/assets.dart';
import 'package:cbi_mobile/core/errors/app_exception.dart';
import 'package:cbi_mobile/core/security/biometric_auth.dart';
import 'package:cbi_mobile/core/storage/lock_settings_store.dart';
import 'package:cbi_mobile/core/storage/remembered_credentials_store.dart';
import 'package:cbi_mobile/core/storage/session_store.dart';
import 'package:cbi_mobile/core/theme/app_palette.dart';
import 'package:cbi_mobile/features/auth/login_screen.dart';
import 'package:cbi_mobile/features/lock/app_lock_controller.dart';
import 'package:cbi_mobile/features/shell/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  Future<void> pumpLogin(
    WidgetTester tester,
    FakeRepository repo, {
    SessionStore? store,
    RememberedCredentialsStore? remembered,
    LockSettingsStore? lockStore,
    BiometricAuth? biometrics,
    ThemeMode themeMode = ThemeMode.system,
  }) async {
    await tester.pumpWidget(
      testApp(
        const LoginScreen(),
        repo: repo,
        store: store,
        remembered: remembered,
        lockStore: lockStore,
        biometrics: biometrics,
        scaffold: false,
        themeMode: themeMode,
      ),
    );
    await tester.pump();
  }

  TextField field(WidgetTester tester, String key) => tester.widget<TextField>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)),
  );

  Checkbox rememberBox(WidgetTester tester) => tester.widget<Checkbox>(
    find.descendant(
      of: find.byKey(const Key('login-remember')),
      matching: find.byType(Checkbox),
    ),
  );

  const saved = RememberedCredentials(username: 'H0017549', password: 'secret');

  Finder assetImage(String name) => find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == name,
  );

  testWidgets('shows the legacy login texts and styles', (tester) async {
    await pumpLogin(tester, FakeRepository());

    expect(find.text('Email | AD 2000'), findsOneWidget);
    expect(find.text('Mot de Passe'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Vos tableaux de bord, partout'), findsOneWidget);
    expect(find.text('Cellule Business Intelligence · GSH'), findsOneWidget);
    // One blurred glass panel holds the form.
    expect(
      find.descendant(
        of: find.byKey(const Key('login-panel')),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
    // Unauthenticated ticket creation is impossible: no "Signaler" link.
    expect(find.textContaining('Signaler'), findsNothing);
    // Full Portail BI logo on top (dark lettering in the light theme).
    expect(assetImage(AppAssets.loginLogo(Brightness.light)), findsOneWidget);
    expect(AppAssets.loginLogo(Brightness.light), AppAssets.portailLogoOnLight);
    expect(find.text('CBI'), findsNothing);

    final password = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('login-password')),
        matching: find.byType(TextField),
      ),
    );
    expect(password.obscureText, isTrue);
    expect(password.style?.color, AppPalette.light.text);
    // Glass input, green (70%) 1.5px border on focus.
    final theme = Theme.of(tester.element(find.byType(TextField).first));
    final inputs = theme.inputDecorationTheme;
    expect(inputs.filled, isTrue);
    expect(inputs.fillColor, AppPalette.light.surfaceAlt);
    expect(
      inputs.focusedBorder?.borderSide.color,
      AppPalette.light.focusBorder,
    );
    expect(inputs.focusedBorder?.borderSide.width, 1.5);
    expect(inputs.focusedBorder, isA<OutlineInputBorder>());
  });

  testWidgets('dark theme uses the light-lettered logo', (tester) async {
    await pumpLogin(tester, FakeRepository(), themeMode: ThemeMode.dark);
    expect(assetImage(AppAssets.portailLogoOnDark), findsOneWidget);
    expect(
      AppAssets.portailLogoOnDark,
      'assets/images/brand/portail_bi_logo_on_dark.png',
    );
    expect(
      AppAssets.portailLogoOnLight,
      'assets/images/brand/portail_bi_logo.png',
    );
    // Shown ~220 wide.
    expect(tester.getSize(find.byType(Image)).width, lessThanOrEqualTo(220));
    expect(assetImage(AppAssets.portailLogoOnLight), findsNothing);
    final password = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('login-password')),
        matching: find.byType(TextField),
      ),
    );
    expect(password.style?.color, AppPalette.dark.text);
  });

  testWidgets('validates required fields', (tester) async {
    await pumpLogin(tester, FakeRepository());
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    expect(find.text('Username obligatoire'), findsOneWidget);
    expect(find.text('Mot de passe obligatoire'), findsOneWidget);
  });

  testWidgets('shows invalid credentials under the password', (tester) async {
    final repo = FakeRepository()
      ..loginError = const ApiException(
        statusCode: 401,
        code: 'invalid_credentials',
        detail: 'Identifiants invalides.',
      );
    await pumpLogin(tester, repo);
    await tester.enterText(find.byType(TextField).first, 'H0017549');
    await tester.enterText(find.byType(TextField).last, 'wrong');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Email ou mot de passe invalide'), findsOneWidget);
  });

  testWidgets('network failure shows the legacy toast', (tester) async {
    final repo = FakeRepository()..loginError = const NetworkException();
    await pumpLogin(tester, repo);
    await tester.enterText(find.byType(TextField).first, 'H0017549');
    await tester.enterText(find.byType(TextField).last, 'secret');
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Vérifiez votre connexion internet'), findsOneWidget);
  });

  testWidgets('prefills the last username', (tester) async {
    await pumpLogin(
      tester,
      FakeRepository(),
      store: MemorySessionStore(lastUsername: 'H0017549'),
    );
    await tester.pump();
    expect(find.text('H0017549'), findsOneWidget);
  });

  group('Se souvenir de moi', () {
    testWidgets('checkbox under the password, on by default', (tester) async {
      await pumpLogin(tester, FakeRepository());
      expect(find.text('Se souvenir de moi'), findsOneWidget);
      expect(rememberBox(tester).value, isTrue);
      expect(
        tester.getTopLeft(find.byKey(const Key('login-remember'))).dy,
        greaterThan(tester.getTopLeft(find.byKey(const Key('login-password'))).dy),
      );
      await tester.tap(find.text('Se souvenir de moi'));
      await tester.pump();
      expect(rememberBox(tester).value, isFalse);
    });

    testWidgets('prefills the remembered username and (obscured) password', (
      tester,
    ) async {
      await pumpLogin(
        tester,
        FakeRepository(),
        store: MemorySessionStore(lastUsername: 'someone-else'),
        remembered: MemoryRememberedCredentialsStore(saved),
      );
      await tester.pump();
      expect(field(tester, 'login-username').controller!.text, 'H0017549');
      final password = field(tester, 'login-password');
      expect(password.controller!.text, 'secret');
      expect(password.obscureText, isTrue);
      // The remembered password can't be revealed with the eye button.
      expect(find.byTooltip('Afficher le mot de passe'), findsNothing);
    });

    testWidgets('login with the box off forgets the remembered credentials', (
      tester,
    ) async {
      final remembered = MemoryRememberedCredentialsStore(saved);
      final repo = FakeRepository();
      await pumpLogin(tester, repo, remembered: remembered);
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, 'typed');
      await tester.tap(find.text('Se souvenir de moi'));
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
      expect(repo.logins.single, ('H0017549', 'typed'));
      expect(find.byType(ShellScreen), findsOneWidget);
      expect(await remembered.read(), isNull);
    });

    testWidgets('login with the box on saves the credentials', (tester) async {
      final remembered = MemoryRememberedCredentialsStore();
      await pumpLogin(tester, FakeRepository(), remembered: remembered);
      await tester.enterText(find.byType(TextField).first, ' H0017549 ');
      await tester.enterText(find.byType(TextField).last, 'pw');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
      final kept = await remembered.read();
      expect(kept?.username, 'H0017549');
      expect(kept?.password, 'pw');
    });
  });

  group('Connexion par empreinte', () {
    for (final (label, lockOn, status, shown) in [
      ('lock off', false, BiometricStatus.biometrics, false),
      ('no biometrics', true, BiometricStatus.unavailable, false),
      ('lock on + fingerprint', true, BiometricStatus.biometrics, true),
      ('lock on + device PIN', true, BiometricStatus.deviceCredential, true),
    ]) {
      testWidgets('button: $label', (tester) async {
        await pumpLogin(
          tester,
          FakeRepository(),
          remembered: MemoryRememberedCredentialsStore(saved),
          lockStore: MemoryLockSettingsStore(LockSettings(enabled: lockOn)),
          biometrics: FakeBiometricAuth(current: status),
        );
        await tester.pumpAndSettle();
        expect(
          find.byTooltip('Connexion par empreinte'),
          shown ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('hidden when no password is remembered', (tester) async {
      await pumpLogin(
        tester,
        FakeRepository(),
        remembered: MemoryRememberedCredentialsStore(
          const RememberedCredentials(username: 'H0017549'),
        ),
        lockStore: MemoryLockSettingsStore(const LockSettings(enabled: true)),
        biometrics: FakeBiometricAuth(),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-biometric')), findsNothing);
    });

    testWidgets('prompt, then login with the remembered credentials', (
      tester,
    ) async {
      final repo = FakeRepository();
      final biometrics = FakeBiometricAuth();
      await pumpLogin(
        tester,
        repo,
        remembered: MemoryRememberedCredentialsStore(saved),
        lockStore: MemoryLockSettingsStore(const LockSettings(enabled: true)),
        biometrics: biometrics,
      );
      await tester.pumpAndSettle();
      // Whatever is typed, the remembered credentials are used.
      await tester.enterText(find.byType(TextField).first, 'edited');
      await tester.tap(find.byKey(const Key('login-biometric')));
      await tester.pumpAndSettle();
      expect(biometrics.reasons, [LockPrompts.login]);
      expect(repo.logins.single, ('H0017549', 'secret'));
      expect(find.byType(ShellScreen), findsOneWidget);
    });

    testWidgets('cancelled prompt: no login', (tester) async {
      final repo = FakeRepository();
      await pumpLogin(
        tester,
        repo,
        remembered: MemoryRememberedCredentialsStore(saved),
        lockStore: MemoryLockSettingsStore(const LockSettings(enabled: true)),
        biometrics: FakeBiometricAuth(succeed: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('login-biometric')));
      await tester.pumpAndSettle();
      expect(repo.logins, isEmpty);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('offer to enable the lock after the first login', () {
    Future<void> loginOnce(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).first, 'H0017549');
      await tester.enterText(find.byType(TextField).last, 'pw');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
    }

    const question = 'Activer le déverrouillage par empreinte ?';

    testWidgets('"Activer" prompts and enables the lock', (tester) async {
      final lockStore = MemoryLockSettingsStore();
      final biometrics = FakeBiometricAuth();
      await pumpLogin(
        tester,
        FakeRepository(),
        lockStore: lockStore,
        biometrics: biometrics,
      );
      await loginOnce(tester);
      expect(find.byType(ShellScreen), findsOneWidget);
      expect(find.text(question), findsOneWidget);
      await tester.tap(find.byKey(const Key('enable-lock-accept')));
      await tester.pumpAndSettle();
      expect(biometrics.reasons, [LockPrompts.enable]);
      expect(lockStore.settings.enabled, isTrue);
      expect(lockStore.settings.offered, isTrue);
      expect(find.text(question), findsNothing);
    });

    testWidgets('"Plus tard" is remembered: offered only once', (tester) async {
      final lockStore = MemoryLockSettingsStore();
      await pumpLogin(
        tester,
        FakeRepository(),
        lockStore: lockStore,
        biometrics: FakeBiometricAuth(),
      );
      await loginOnce(tester);
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
      expect(find.text(question), findsNothing);
      expect(lockStore.settings.enabled, isFalse);
      expect(lockStore.settings.offered, isTrue);
    });

    for (final (label, settings, status) in [
      ('no fingerprint enrolled', const LockSettings(), BiometricStatus.deviceCredential),
      ('already offered', const LockSettings(offered: true), BiometricStatus.biometrics),
      ('lock already on', const LockSettings(enabled: true), BiometricStatus.biometrics),
    ]) {
      testWidgets('not offered: $label', (tester) async {
        await pumpLogin(
          tester,
          FakeRepository(),
          lockStore: MemoryLockSettingsStore(settings),
          biometrics: FakeBiometricAuth(current: status),
        );
        await loginOnce(tester);
        expect(find.byType(ShellScreen), findsOneWidget);
        expect(find.text(question), findsNothing);
      });
    }
  });
}
