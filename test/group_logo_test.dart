import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cbi_mobile/core/config/app_config.dart';
import 'package:cbi_mobile/core/images/logo_images.dart';
import 'package:cbi_mobile/core/providers.dart';
import 'package:cbi_mobile/core/widgets/group_logo.dart';
import 'package:cbi_mobile/data/models/catalog.dart';
import 'package:cbi_mobile/data/repositories/demo_fixtures.dart';
import 'package:cbi_mobile/features/home/home_tiles.dart';
import 'package:cbi_mobile/features/home/home_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/contract_fixtures.dart';
import 'support/test_app.dart';

/// Image provider resolving synchronously to a ready-made [ui.Image].
class _ReadyImage extends ImageProvider<_ReadyImage> {
  _ReadyImage(this.image);

  final ui.Image image;

  @override
  Future<_ReadyImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_ReadyImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(SynchronousFuture(ImageInfo(image: image)));
}

/// Image provider whose download fails (404, network…).
class _FailingImage extends ImageProvider<_FailingImage> {
  const _FailingImage();

  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_FailingImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
        Future<ImageInfo>.error(StateError('404 logo')),
      );
}

class _FakeCacheManager extends Fake implements BaseCacheManager {}

void main() {
  late ui.Image image;
  setUpAll(() async => image = await createTestImage(width: 4, height: 4));

  final catalog = Catalog.fromJson(contractCatalog());

  testWidgets('société with logo_url shows the logo, others the initials', (
    tester,
  ) async {
    final requested = <String>[];
    await tester.pumpWidget(
      testApp(
        const HomeView(),
        // Consolidé + Société: the home is shown (no single-group skip).
        repo: FakeRepository(catalog: Catalog.fromJson(contractCatalog())),
        logoResolver: (url) {
          requested.add(url);
          return _ReadyImage(image);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(requested, ['/mobile/v1/metadata/9/logo/?v=societe-3f2a9c1b7d4e']);
    final mdm = find.widgetWithText(GroupCard, 'MDM');
    expect(mdm, findsOneWidget, reason: 'name under the logo');
    expect(
      find.descendant(of: mdm, matching: find.byType(LogoTile)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mdm, matching: find.byKey(const Key('group-logo-loaded'))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mdm, matching: find.byType(InitialsTile)),
      findsNothing,
    );
    // Consolidé direction card without logo: code in the tile, name under it.
    final dfc = find.byType(ConsolideCard);
    expect(
      find.descendant(of: dfc, matching: find.byType(InitialsTile)),
      findsOneWidget,
    );
    expect(find.descendant(of: dfc, matching: find.text('DFC')), findsOneWidget);
    expect(
      find.descendant(
        of: dfc,
        matching: find.text('Direction Finance et Comptabilité'),
      ),
      findsOneWidget,
    );
    expect(catalog.sections[1].groups.single.logoUrl, isNotNull);
  });

  testWidgets('logo card: 88 wide, name limited to 2 lines, white tile', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        Center(
          child: GroupCard(
            code: 'MDM',
            name: 'Société au nom beaucoup trop long pour tenir sur deux lignes',
            logoUrl: '/logo',
            onTap: () {},
          ),
        ),
        repo: FakeRepository(),
        themeMode: ThemeMode.dark,
        logoResolver: (_) => _ReadyImage(image),
      ),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(GroupCard)).width, 88);
    final name = tester.widget<Text>(find.textContaining('Société au nom'));
    expect(name.maxLines, 2);
    expect(name.overflow, TextOverflow.ellipsis);
    expect(name.textAlign, TextAlign.center);
    expect(name.style?.fontSize, 12);
    final tile = tester.widget<Container>(
      find.byKey(const Key('group-logo-loaded')),
    );
    expect((tile.decoration! as BoxDecoration).color, Colors.white);
    expect(tester.getSize(find.byKey(const Key('group-logo-loaded'))), const Size(64, 64));
  });

  testWidgets('no logo_url → initials tile', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      testApp(
        Center(child: GroupCard(code: 'PI', name: 'Pôle Industrie', onTap: () {})),
        repo: FakeRepository(),
        logoResolver: (_) {
          calls++;
          return _ReadyImage(image);
        },
      ),
    );
    await tester.pump();
    expect(calls, 0);
    expect(find.byType(LogoTile), findsNothing);
    expect(find.byType(InitialsTile), findsOneWidget);
    expect(find.text('PI'), findsOneWidget);
    expect(find.text('Pôle Industrie'), findsOneWidget);
  });

  testWidgets('failed download falls back to the initials tile', (tester) async {
    await tester.pumpWidget(
      testApp(
        Center(
          child: GroupCard(
            code: 'MDM',
            name: 'MDM',
            logoUrl: '/mobile/v1/metadata/9/logo/?v=x',
            onTap: () {},
          ),
        ),
        repo: FakeRepository(),
        logoResolver: (_) => const _FailingImage(),
      ),
    );
    // Loading placeholder first (not the white tile yet).
    expect(find.byType(LogoTile), findsOneWidget);
    expect(find.byKey(const Key('group-logo-loaded')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(InitialsTile), findsOneWidget);
    expect(find.byKey(const Key('group-logo-loaded')), findsNothing);
  });

  group('logo resolver', () {
    ProviderContainer container({required bool demo}) {
      final c = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig(apiBaseUrl: 'http://10.10.10.53:8222', demoMode: demo),
          ),
          logoCacheManagerProvider.overrideWithValue(_FakeCacheManager()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('resolves against API_BASE_URL with the Bearer header', () {
      final c = container(demo: false);
      c.read(apiClientProvider).token = 'abc';
      final provider =
          c.read(logoImageResolverProvider)(
                '/mobile/v1/metadata/9/logo/?v=societe-3f2a9c1b7d4e',
              )!
              as CachedNetworkImageProvider;
      expect(
        provider.url,
        'http://10.10.10.53:8222/mobile/v1/metadata/9/logo/?v=societe-3f2a9c1b7d4e',
      );
      expect(provider.headers, {'Authorization': 'Bearer abc'});
      expect(provider.cacheManager, isA<_FakeCacheManager>());
    });

    test('never sends the token to another host', () {
      final c = container(demo: false);
      c.read(apiClientProvider).token = 'abc';
      final provider =
          c.read(logoImageResolverProvider)('http://evil.example.com/logo.png')!
              as CachedNetworkImageProvider;
      expect(provider.headers, isEmpty);
    });

    test('demo mode maps fixture logos to bundled images', () {
      final c = container(demo: true);
      final json = demoCatalogJson();
      final logos = [
        for (final s in (json['sections'] as List).cast<Map<String, dynamic>>())
          for (final g in (s['groups'] as List).cast<Map<String, dynamic>>())
            if (g['logo_url'] != null) g['logo_url'] as String,
      ];
      expect(logos, isNotEmpty);
      for (final url in logos) {
        expect(c.read(logoImageResolverProvider)(url), isA<AssetImage>());
      }
      expect(c.read(logoImageResolverProvider)('/mobile/v1/metadata/1/logo/'), isNull);
    });
  });

  test('cache keeps versioned logos forever', () async {
    final service = ImmutableFileService(_StaticFileService());
    final response = await service.get('http://x/logo');
    expect(
      response.validTill.isAfter(DateTime.now().add(const Duration(days: 3000))),
      isTrue,
    );
    expect(response.statusCode, 200);
  });
}

class _StaticFileService extends FileService {
  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) async =>
      _Response();
}

class _Response implements FileServiceResponse {
  @override
  Stream<List<int>> get content => const Stream.empty();
  @override
  int? get contentLength => 0;
  @override
  String? get eTag => null;
  @override
  String get fileExtension => '.png';
  @override
  int get statusCode => 200;
  @override
  DateTime get validTill => DateTime.now();
}
