import 'package:cbi_mobile/core/security/biometric_auth.dart';
import 'package:cbi_mobile/core/storage/lock_settings_store.dart';
import 'package:cbi_mobile/features/lock/app_lock_controller.dart';
import 'package:cbi_mobile/features/settings/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  Future<void> pumpSettings(
    WidgetTester tester, {
    required MemoryLockSettingsStore lockStore,
    required FakeBiometricAuth biometrics,
  }) async {
    await tester.pumpWidget(
      testApp(
        const SettingsView(),
        repo: FakeRepository(),
        lockStore: lockStore,
        biometrics: biometrics,
      ),
    );
    await tester.pumpAndSettle();
  }

  Switch lockSwitch(WidgetTester tester) => tester.widget<Switch>(
    find.descendant(
      of: find.byKey(const Key('lock-switch')),
      matching: find.byType(Switch),
    ),
  );

  testWidgets('Sécurité section: lock switch only, no delay while off', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      lockStore: MemoryLockSettingsStore(),
      biometrics: FakeBiometricAuth(),
    );
    expect(find.text('Sécurité'), findsOneWidget);
    expect(find.text('Verrouillage par empreinte'), findsOneWidget);
    expect(lockSwitch(tester).value, isFalse);
    expect(lockSwitch(tester).onChanged, isNotNull);
    expect(find.text('Délai de verrouillage'), findsNothing);
    // No "remember my credentials" switch in the settings.
    expect(find.text('Se souvenir de mes identifiants'), findsNothing);
  });

  testWidgets('disabled with a hint when nothing is configured', (tester) async {
    await pumpSettings(
      tester,
      lockStore: MemoryLockSettingsStore(),
      biometrics: FakeBiometricAuth(current: BiometricStatus.unavailable),
    );
    expect(
      find.text('Aucune empreinte ou code configuré sur ce téléphone'),
      findsOneWidget,
    );
    expect(lockSwitch(tester).onChanged, isNull);
  });

  testWidgets('enabling requires a successful prompt, then the delay shows', (
    tester,
  ) async {
    final lockStore = MemoryLockSettingsStore();
    final biometrics = FakeBiometricAuth();
    await pumpSettings(tester, lockStore: lockStore, biometrics: biometrics);

    await tester.tap(find.byKey(const Key('lock-switch')));
    await tester.pumpAndSettle();
    expect(biometrics.reasons, [LockPrompts.enable]);
    expect(lockStore.settings.enabled, isTrue);
    expect(lockSwitch(tester).value, isTrue);
    expect(find.text('Délai de verrouillage'), findsOneWidget);
    expect(find.text('1 min'), findsOneWidget); // default

    await tester.tap(find.byKey(const Key('lock-delay')));
    await tester.pumpAndSettle();
    for (final label in ['Immédiat', '1 min', '5 min', '15 min']) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.byKey(const Key('lock-delay-fiveMinutes')));
    await tester.pumpAndSettle();
    expect(lockStore.settings.delay, LockDelay.fiveMinutes);
    expect(find.text('5 min'), findsOneWidget);

    // Off: no prompt needed, delay hidden again.
    await tester.tap(find.byKey(const Key('lock-switch')));
    await tester.pumpAndSettle();
    expect(lockStore.settings.enabled, isFalse);
    expect(biometrics.reasons, hasLength(1));
    expect(find.text('Délai de verrouillage'), findsNothing);
  });

  testWidgets('failed prompt: the lock stays off', (tester) async {
    final lockStore = MemoryLockSettingsStore();
    await pumpSettings(
      tester,
      lockStore: lockStore,
      biometrics: FakeBiometricAuth(succeed: false),
    );
    await tester.tap(find.byKey(const Key('lock-switch')));
    await tester.pumpAndSettle();
    expect(lockStore.settings.enabled, isFalse);
    expect(lockSwitch(tester).value, isFalse);
    expect(find.text('Verrouillage non activé.'), findsOneWidget);
  });

  testWidgets('logout dialog has no "forget" option', (tester) async {
    await pumpSettings(
      tester,
      lockStore: MemoryLockSettingsStore(),
      biometrics: FakeBiometricAuth(),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('logout-button')),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    expect(find.text('Voulez-vous vraiment vous déconnecter?'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.textContaining('Oublier'), findsNothing);
  });
}
