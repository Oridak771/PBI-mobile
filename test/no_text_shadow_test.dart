import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Portail BI style has no text shadows (and no legacy colours).
void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('no text shadow anywhere in lib/', () {
    expect(sources, isNotEmpty);
    final offenders = [
      for (final f in sources)
        if (RegExp(r'\bShadow\(|shadows:|AppShadows').hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });

  test('widgets use the palette, not the legacy colour constants', () {
    const legacy = [
      'AppColors.black',
      'AppColors.gray',
      'AppColors.surface',
      'AppColors.sheet',
      'AppColors.blue',
      'AppColors.tint',
      'AppColors.greyText',
    ];
    final offenders = [
      for (final f in sources)
        for (final token in legacy)
          if (f.readAsStringSync().contains(RegExp('${RegExp.escape(token)}\\b')))
            '${f.path}: $token',
    ];
    expect(offenders, isEmpty);
  });
}
