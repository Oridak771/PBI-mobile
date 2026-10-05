import 'package:cbi_mobile/core/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('long press on the title fires the hidden callback', (tester) async {
    var longPresses = 0;
    await tester.pumpWidget(
      testApp(
        ScreenHeader(title: 'Encaissement Clients', onTitleLongPress: () => longPresses++),
        repo: FakeRepository(),
      ),
    );
    await tester.tap(find.text('Encaissement Clients'));
    await tester.pump();
    expect(longPresses, 0);
    await tester.longPress(find.text('Encaissement Clients'));
    await tester.pump();
    expect(longPresses, 1);
    // No visible affordance: no extra button in the header.
    expect(find.byType(IconButton), findsOneWidget); // "Retour" only
  });
}
