import 'package:cbi_mobile/data/models/catalog.dart';
import 'package:cbi_mobile/features/viewer/ntlm_auth.dart';
import 'package:cbi_mobile/features/viewer/viewer_variant.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/contract_fixtures.dart';

void main() {
  const portrait = Orientation.portrait;
  const landscape = Orientation.landscape;

  group('selectReportVariant', () {
    test('portrait → mobile, landscape → desktop', () {
      expect(selectReportVariant(orientation: portrait), ReportVariant.mobile);
      expect(selectReportVariant(orientation: landscape), ReportVariant.desktop);
    });

    test('manual choice wins over the orientation', () {
      for (final o in Orientation.values) {
        for (final manual in ReportVariant.values) {
          expect(selectReportVariant(orientation: o, manual: manual), manual);
        }
      }
    });
  });

  group('viewerModeFor', () {
    test('a phone edition keeps priority for "mobile"', () {
      expect(
        viewerModeFor(ReportVariant.mobile, hasPhoneEdition: true),
        ViewerMode.phoneEdition,
      );
      expect(
        viewerModeFor(ReportVariant.mobile, hasPhoneEdition: false),
        ViewerMode.mobileLayout,
      );
      for (final phone in [true, false]) {
        expect(
          viewerModeFor(ReportVariant.desktop, hasPhoneEdition: phone),
          ViewerMode.desktop,
        );
      }
    });
  });

  test('toggle: phone edition or backend phone layout', () {
    expect(
      showVariantToggle(hasPhoneEdition: true, mobileLayoutAvailable: false),
      isTrue,
    );
    expect(
      showVariantToggle(hasPhoneEdition: false, mobileLayoutAvailable: true),
      isTrue,
    );
    expect(
      showVariantToggle(hasPhoneEdition: false, mobileLayoutAvailable: false),
      isFalse,
    );
  });

  group('resolveViewerTarget', () {
    const full = 'http://10.20.10.63/Reports/powerbi/x?rs:embed=true';
    const phone = PhoneEdition(
      id: 31,
      serverId: 2,
      embedUrl: 'http://pbirs-mobile.gsh.local/Reports/powerbi/x%20(t)?rs:embed=true',
    );

    test('phone edition: portrait → phone URL without scripts', () {
      final target = resolveViewerTarget(
        orientation: portrait,
        fullUrl: full,
        phone: phone,
      );
      expect(target, (
        mode: ViewerMode.phoneEdition,
        variant: ReportVariant.mobile,
        url: phone.embedUrl,
      ));
      expect(target.injectsScripts, isFalse);
    });

    test('phone edition: landscape / "Bureau" → full report, no scripts', () {
      final expected = (
        mode: ViewerMode.desktop,
        variant: ReportVariant.desktop,
        url: full,
      );
      expect(
        resolveViewerTarget(orientation: landscape, fullUrl: full, phone: phone),
        expected,
      );
      expect(
        resolveViewerTarget(
          orientation: portrait,
          fullUrl: full,
          phone: phone,
          manual: ReportVariant.desktop,
        ),
        expected,
      );
    });

    test('no phone edition: portrait → full report with the scripts', () {
      final target = resolveViewerTarget(orientation: portrait, fullUrl: full);
      expect(target, (
        mode: ViewerMode.mobileLayout,
        variant: ReportVariant.mobile,
        url: full,
      ));
      expect(target.injectsScripts, isTrue);

      final desktop = resolveViewerTarget(orientation: landscape, fullUrl: full);
      expect(desktop.mode, ViewerMode.desktop);
      expect(desktop.url, full);
      expect(desktop.injectsScripts, isFalse);

      // "Mobile" chosen in landscape.
      final manual = resolveViewerTarget(
        orientation: landscape,
        fullUrl: full,
        manual: ReportVariant.mobile,
      );
      expect(manual.mode, ViewerMode.mobileLayout);
      expect(manual.injectsScripts, isTrue);
    });

    test('an empty phone URL means no phone edition', () {
      final target = resolveViewerTarget(
        orientation: portrait,
        fullUrl: full,
        phone: const PhoneEdition(id: 1, embedUrl: ' '),
      );
      expect(target.mode, ViewerMode.mobileLayout);
      expect(target.url, full);
    });
  });

  test('mode labels (info sheet)', () {
    expect(ViewerMode.mobileLayout.label, 'mobile');
    expect(ViewerMode.desktop.label, 'bureau');
    expect(ViewerMode.phoneEdition.label, 'édition téléphone');
  });

  test('NTLM allowlist accepts the phone edition host', () {
    final catalog = Catalog.fromJson(contractCatalog());
    final phone = catalog.reports[12]!.phone!;
    final hosts = viewerAllowedHosts(
      catalog: catalog,
      openedServer: catalog.servers.first,
      phone: phone,
    );
    expect(hosts, {'10.20.10.63', 'pbirs-mobile.gsh.local'});
    final host = Uri.parse(phone.embedUrl).host;
    expect(isAllowedPbiHost(host, hosts), isTrue);
    expect(isAllowedPbiHost('evil.example.com', hosts), isFalse);

    // Without a catalog, only the open response's server.
    expect(
      viewerAllowedHosts(openedServer: catalog.servers.first, phone: phone),
      {'10.20.10.63'},
    );
  });
}
