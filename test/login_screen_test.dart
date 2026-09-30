import 'package:cbi_mobile/core/assets.dart';
import 'package:cbi_mobile/core/errors/app_exception.dart';
import 'package:cbi_mobile/core/storage/session_store.dart';
import 'package:cbi_mobile/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  Future<void> pumpLogin(
    WidgetTester tester,
    FakeRepository repo, {
    SessionStore? store,
  }) async {
    await tester.pumpWidget(
      testApp(const LoginScreen(), repo: repo, store: store, scaffold: false),
    );
    await tester.pump();
  }

  testWidgets('shows the legacy login texts and styles', (tester) async {
    await pumpLogin(tester, FakeRepository());

    expect(find.text('Email | AD 2000'), findsOneWidget);
    expect(find.text('Mot de Passe'), findsOneWidget);
    expect(find.text('CONNEXION'), findsOneWidget);
    // Portail BI brand logo on top; no footer logo has been chosen yet.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == AppAssets.loginLogo,
      ),
      findsOneWidget,
    );
    expect(find.text('CBI'), findsNothing);

    final password = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('login-password')),
        matching: find.byType(TextField),
      ),
    );
    expect(password.obscureText, isTrue);
    expect(password.textAlign, TextAlign.center);
    expect(password.style?.color, const Color(0xFFF2F2F2));
  });

  testWidgets('validates required fields', (tester) async {
    await pumpLogin(tester, FakeRepository());
    await tester.tap(find.text('CONNEXION'));
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
    await tester.tap(find.text('CONNEXION'));
    await tester.pumpAndSettle();
    expect(find.text('Email ou mot de passe invalide'), findsOneWidget);
  });

  testWidgets('network failure shows the legacy toast', (tester) async {
    final repo = FakeRepository()..loginError = const NetworkException();
    await pumpLogin(tester, repo);
    await tester.enterText(find.byType(TextField).first, 'H0017549');
    await tester.enterText(find.byType(TextField).last, 'secret');
    await tester.tap(find.text('CONNEXION'));
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
}
