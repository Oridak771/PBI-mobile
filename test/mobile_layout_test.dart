import 'dart:async';
import 'dart:convert';

import 'package:cbi_mobile/core/api/api_client.dart';
import 'package:cbi_mobile/core/config/app_config.dart';
import 'package:cbi_mobile/data/models/mobile_layout.dart';
import 'package:cbi_mobile/data/repositories/api_cbi_repository.dart';
import 'package:cbi_mobile/data/repositories/demo_cbi_repository.dart';
import 'package:cbi_mobile/features/viewer/mobile_layout_support.dart';
import 'package:cbi_mobile/features/viewer/viewer_variant.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/test_app.dart';

/// Shape of CBI/docs/MOBILE_API.md `GET reports/<id>/mobile-layout/`.
Map<String, dynamic> contractMobileLayout() => {
  'available': true,
  'version': 1,
  'pages': {
    'ReportSection': {
      'display_name': 'CA GLOBAL',
      'width': 324,
      'height': 1514,
      'visuals': {
        'b7b6a95e2ea9445b6096': {
          'x': 10,
          'y': 55.5,
          'z': 3000,
          'width': 144,
          'height': 100,
          'objects': {
            'labels': [
              {
                'properties': {
                  'fontSize': {
                    'expr': {'Literal': {'Value': '9D'}},
                  },
                },
              },
            ],
          },
        },
        'c0ffee': {'x': 0, 'y': 0, 'z': 0, 'width': 320, 'height': 40},
      },
    },
    'ReportSection2': {
      'display_name': 'DÉTAIL',
      'width': 320,
      'height': 600,
      'visuals': <String, dynamic>{},
    },
  },
};

Future<MobileLayout> _never() => Completer<MobileLayout>().future;

void main() {
  group('MobileLayout.fromJson', () {
    test('parses the contract payload', () {
      final layout = MobileLayout.fromJson(contractMobileLayout());
      expect(layout.available, isTrue);
      expect(layout.version, 1);
      expect(layout.hasPages, isTrue);
      expect(layout.pages.keys, ['ReportSection', 'ReportSection2']);
      final page = layout.pages['ReportSection']!;
      expect(page.displayName, 'CA GLOBAL');
      expect(page.width, 324);
      expect(page.height, 1514);
      final visual = page.visuals['b7b6a95e2ea9445b6096']!;
      expect(
        [visual.x, visual.y, visual.z, visual.width, visual.height],
        [10, 55.5, 3000, 144, 100],
      );
      expect(visual.objects!['labels'], isA<List<dynamic>>());
      expect(page.visuals['c0ffee']!.objects, isNull);
    });

    test('unavailable / malformed payloads', () {
      final none = MobileLayout.fromJson({'available': false, 'pages': {}});
      expect(none.available, isFalse);
      expect(none.hasPages, isFalse);

      final odd = MobileLayout.fromJson({
        'available': 'true',
        'pages': {
          'A': 'not a page',
          'B': {
            'width': '320',
            'visuals': {'v': 'nope', 'w': {'x': null, 'objects': []}},
          },
        },
      });
      expect(odd.available, isTrue);
      expect(odd.pages.keys, ['B']);
      expect(odd.pages['B']!.width, 320);
      expect(odd.pages['B']!.visuals.keys, ['w']);
      expect(odd.pages['B']!.visuals['w']!.objects, isNull);

      // available=true but nothing to inject.
      expect(MobileLayout.fromJson({'available': true}).hasPages, isFalse);
      expect(MobileLayout.fromJson({}).available, isFalse);
    });

    test('toScriptJson is what the asset script reads', () {
      final json = MobileLayout.fromJson(contractMobileLayout()).toScriptJson();
      expect(json.keys, ['pages']);
      final visual =
          (json['pages'] as Map)['ReportSection']['visuals']['b7b6a95e2ea9445b6096']
              as Map;
      expect(visual['x'], 10);
      expect(visual['y'], 55.5);
      expect(visual['objects'], contractMobileLayout()['pages']['ReportSection']
          ['visuals']['b7b6a95e2ea9445b6096']['objects']);
      final plain =
          (json['pages'] as Map)['ReportSection']['visuals']['c0ffee'] as Map;
      expect(plain.containsKey('objects'), isFalse);
    });
  });

  group('repositories', () {
    test('API: GET reports/<id>/mobile-layout/', () async {
      late http.Request seen;
      final repo = ApiCbiRepository(
        ApiClient(
          config: const AppConfig(
            apiBaseUrl: 'http://10.10.10.53:8222',
            demoMode: false,
          ),
          httpClient: MockClient((request) async {
            seen = request;
            return http.Response.bytes(
              utf8.encode(jsonEncode(contractMobileLayout())),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      )..token = 'abc';
      final layout = await repo.fetchMobileLayout(12);
      expect(seen.method, 'GET');
      expect(
        seen.url.toString(),
        'http://10.10.10.53:8222/mobile/v1/reports/12/mobile-layout/',
      );
      expect(layout.pages['ReportSection2']!.displayName, 'DÉTAIL');
    });

    test('demo: odd ids have a phone layout, even ones none', () async {
      final repo = DemoCbiRepository(latency: Duration.zero);
      final odd = await repo.fetchMobileLayout(1);
      expect(odd.available, isTrue);
      expect(odd.pages['ReportSection']!.visuals, hasLength(2));
      expect((await repo.fetchMobileLayout(2)).available, isFalse);
    });

    test('fake: scripted answer and error', () async {
      final repo = FakeRepository()
        ..mobileLayout = MobileLayout.fromJson(contractMobileLayout());
      expect((await repo.fetchMobileLayout(4)).pages, hasLength(2));
      repo.mobileLayoutError = Exception('boom');
      await expectLater(repo.fetchMobileLayout(4), throwsException);
      expect(repo.mobileLayoutCalls, 2);
    });
  });

  group('MobileLayoutCache', () {
    test('one request per report for the session; failures are retried',
        () async {
      final repo = FakeRepository()..mobileLayoutGate = Completer<void>();
      final cache = MobileLayoutCache(repo);
      final a = cache.fetch(7);
      final b = cache.fetch(7);
      expect(identical(a, b), isTrue);
      repo.mobileLayoutGate!.complete();
      await a;
      await cache.fetch(7);
      expect(repo.mobileLayoutCalls, 1);
      await cache.fetch(8);
      expect(repo.mobileLayoutCalls, 2);

      repo.mobileLayoutError = Exception('offline');
      await expectLater(cache.fetch(9), throwsException);
      await Future<void>.delayed(Duration.zero);
      repo.mobileLayoutError = null;
      expect((await cache.fetch(9)).available, isTrue); // retried (demo: odd id)
      expect(repo.mobileLayoutCalls, 4);
    });
  });

  group('MobileLayoutRequest (wait ≤ budget, then fallback)', () {
    test('returns the map received within the budget', () async {
      final layout = MobileLayout.fromJson(contractMobileLayout());
      final request = MobileLayoutRequest(
        Future.delayed(const Duration(milliseconds: 20), () => layout),
        budget: const Duration(seconds: 5),
      );
      expect(request.status, MobileLayoutStatus.pending);
      expect(await request.wait(), same(layout));
      expect(request.status, MobileLayoutStatus.loaded);
      expect(request.available, isTrue);
    });

    test('timeout → null (script alone), never blocks', () async {
      final request = MobileLayoutRequest(
        _never(),
        budget: const Duration(milliseconds: 50),
      );
      final watch = Stopwatch()..start();
      expect(await request.wait(), isNull);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(request.status, MobileLayoutStatus.pending);
      // Budget spent: later loads do not wait at all.
      expect(request.remaining, Duration.zero);
      final again = Stopwatch()..start();
      expect(await request.wait(), isNull);
      expect(again.elapsed, lessThan(const Duration(milliseconds: 40)));
    });

    test('error → null, failed', () async {
      final request = MobileLayoutRequest(
        Future<MobileLayout>.error(Exception('500')),
      );
      expect(await request.wait(), isNull);
      expect(request.status, MobileLayoutStatus.failed);
      expect(request.available, isFalse);
    });

    test('a late map is used by the next load', () async {
      final completer = Completer<MobileLayout>();
      final request = MobileLayoutRequest(
        completer.future,
        budget: const Duration(milliseconds: 20),
      );
      expect(await request.wait(), isNull); // first portrait load: fallback
      completer.complete(MobileLayout.fromJson(contractMobileLayout()));
      await request.done;
      expect((await request.wait())!.hasPages, isTrue); // after rotation
    });

    test('remaining budget follows the clock', () {
      var now = DateTime(2026, 9, 30, 12);
      final request = MobileLayoutRequest(_never(), clock: () => now);
      expect(request.remaining, mobileLayoutWaitBudget);
      now = now.add(const Duration(seconds: 4));
      expect(request.remaining, const Duration(seconds: 2));
      now = now.add(const Duration(seconds: 4));
      expect(request.remaining, Duration.zero);
      expect(mobileLayoutWaitBudget, const Duration(seconds: 6));
    });
  });

  test('layout source', () {
    final layout = MobileLayout.fromJson(contractMobileLayout());
    expect(layoutSourceFor(ViewerMode.mobileLayout, layout), LayoutSource.server);
    expect(layoutSourceFor(ViewerMode.mobileLayout, null), LayoutSource.fallback);
    expect(
      layoutSourceFor(ViewerMode.mobileLayout, MobileLayout.unavailable),
      LayoutSource.fallback,
    );
    expect(layoutSourceFor(ViewerMode.desktop, layout), LayoutSource.none);
    expect(layoutSourceFor(ViewerMode.phoneEdition, layout), LayoutSource.none);
    expect(
      LayoutSource.values.map((s) => s.label),
      ['serveur', 'repli', 'aucune'],
    );
  });

  group('user scripts', () {
    test('jsonForScript escapes script breakouts and stays valid JSON', () {
      final evil = {
        'name': '</script><script>alert(1)</script>',
        'amp': 'a & b',
        'sep': 'x${String.fromCharCode(0x2028)}y${String.fromCharCode(0x2029)}z',
        'quote': '"\'\\',
      };
      final text = jsonForScript(evil);
      expect(text, isNot(contains('<')));
      expect(text, isNot(contains('>')));
      expect(text, isNot(contains('&')));
      expect(text, isNot(contains(String.fromCharCode(0x2028))));
      expect(text, isNot(contains(String.fromCharCode(0x2029))));
      final backslash = String.fromCharCode(0x5C);
      expect(text, contains('${backslash}u003c/script${backslash}u003e'));
      expect(text, contains('${backslash}u2028'));
      expect(jsonDecode(text), evil);
    });

    test('global script embeds the map with jsonEncode', () {
      final layout = MobileLayout.fromJson({
        ...contractMobileLayout(),
        'pages': {
          ...contractMobileLayout()['pages'] as Map<String, dynamic>,
          "Page'); alert('x": {
            'display_name': '</script>',
            'visuals': <String, dynamic>{},
          },
        },
      });
      final script = mobileLayoutGlobalScript(layout);
      const prefix = 'window.__PBI_MOBILE_LAYOUT__ = ';
      expect(script, startsWith(prefix));
      expect(script, endsWith(';'));
      expect(script, isNot(contains('</script>')));
      final literal = script.substring(prefix.length, script.length - 1);
      expect(jsonDecode(literal), jsonDecode(jsonEncode(layout.toScriptJson())));
    });

    test('sources: map first (only with pages), then the asset', () {
      const asset = '/* asset */';
      final layout = MobileLayout.fromJson(contractMobileLayout());
      final withMap = mobileLayoutScriptSources(assetSource: asset, layout: layout);
      expect(withMap, hasLength(2));
      expect(withMap.first, startsWith('window.__PBI_MOBILE_LAYOUT__ = {"pages":'));
      expect(withMap.last, asset);

      expect(mobileLayoutScriptSources(assetSource: asset), [asset]);
      expect(
        mobileLayoutScriptSources(
          assetSource: asset,
          layout: MobileLayout.unavailable,
        ),
        [asset],
      );
      expect(
        mobileLayoutScriptSources(
          assetSource: asset,
          layout: MobileLayout.fromJson({'available': true, 'pages': {}}),
        ),
        [asset],
      );
    });

    test('document start, every frame', () {
      final scripts = documentStartUserScripts(['a', 'b']);
      expect(scripts.map((s) => s.source), ['a', 'b']);
      for (final s in scripts) {
        expect(s.injectionTime, UserScriptInjectionTime.AT_DOCUMENT_START);
        expect(s.forMainFrameOnly, isFalse);
        expect(s.allowedOriginRules, {'*'});
      }
      expect(documentStartUserScripts(const []), isEmpty);
      expect(
        mobileLayoutStatsExpression,
        'JSON.stringify(window.__pbiMobileLayoutStats||null)',
      );
    });

    test('the asset is bundled', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final source = await loadMobileLayoutAsset(rootBundle);
      expect(source, contains('__PBI_MOBILE_LAYOUT__'));
      expect(source, contains('__pbiMobileLayoutStats'));
      expect(source, contains('modelsandexploration'));
    });
  });

  test('technical info lines', () {
    final request = MobileLayoutRequest(
      Future.value(MobileLayout.fromJson(contractMobileLayout())),
    );
    return request.done.then((_) {
      expect(
        technicalInfoLines(
          mode: ViewerMode.mobileLayout,
          source: LayoutSource.server,
          request: request,
          documentStartSupported: true,
          jsStats: '{"rewritten":1,"pages":2,"errors":0}',
        ),
        [
          'Mode : mobile',
          'Source de la disposition : serveur',
          'Pages téléphone (serveur) : 2',
          'Scripts au démarrage (DOCUMENT_START_SCRIPT) : pris en charge',
          'Compteurs JS : {"rewritten":1,"pages":2,"errors":0}',
        ],
      );
      final lines = technicalInfoLines(
        mode: ViewerMode.desktop,
        source: LayoutSource.none,
        request: null,
        documentStartSupported: false,
        jsStats: null,
      );
      expect(lines[0], 'Mode : bureau');
      expect(lines[1], 'Source de la disposition : aucune');
      expect(lines[3], contains('non pris en charge'));
      expect(lines[4], 'Compteurs JS : indisponibles');
    });
  });
}
