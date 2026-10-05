import 'package:cbi_mobile/core/config/app_config.dart';
import 'package:cbi_mobile/core/utils/formatters.dart';
import 'package:cbi_mobile/data/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isValidApiBaseUrl', () {
    test('accepts HTTPS origins, with or without port', () {
      expect(isValidApiBaseUrl('https://cbi.groupe-hasnaoui.com'), isTrue);
      expect(isValidApiBaseUrl('https://cbi.example.com:8443/'), isTrue);
    });

    test('accepts plain HTTP only on the internal network', () {
      expect(isValidApiBaseUrl(AppConfig.defaultApiBaseUrl), isTrue);
      expect(isValidApiBaseUrl('http://10.10.10.53:8222'), isTrue);
      expect(isValidApiBaseUrl('http://192.168.1.20'), isTrue);
      expect(isValidApiBaseUrl('http://172.16.0.5:8000'), isTrue);
      expect(isValidApiBaseUrl('http://localhost:8000'), isTrue);
      expect(isValidApiBaseUrl('http://cbi.example.com'), isFalse);
      expect(isValidApiBaseUrl('http://8.8.8.8'), isFalse);
      expect(isValidApiBaseUrl('http://172.32.0.1'), isFalse);
    });

    test('rejects paths, queries, fragments, credentials and junk', () {
      expect(isValidApiBaseUrl('https://cbi.example.com/portal'), isFalse);
      expect(isValidApiBaseUrl('https://cbi.example.com?x=1'), isFalse);
      expect(isValidApiBaseUrl('https://cbi.example.com#a'), isFalse);
      expect(isValidApiBaseUrl('https://user:pw@cbi.example.com'), isFalse);
      expect(isValidApiBaseUrl('ftp://10.10.10.53'), isFalse);
      expect(isValidApiBaseUrl('not a url'), isFalse);
      expect(isValidApiBaseUrl(''), isFalse);
    });

    test('builds v1 URLs', () {
      final config = AppConfig(
        apiBaseUrl: AppConfig.normalizeBaseUrl('http://10.10.10.53:8222/'),
        demoMode: false,
      );
      expect(
        config.resolve('catalog/').toString(),
        'http://10.10.10.53:8222/mobile/v1/catalog/',
      );
      expect(
        config.resolve('/mobile/v1/me/photo/').toString(),
        'http://10.10.10.53:8222/mobile/v1/me/photo/',
      );
      expect(
        config.resolve('notifications/', {'after': '8'}).toString(),
        'http://10.10.10.53:8222/mobile/v1/notifications/?after=8',
      );
      // Versioned logo URLs keep their query string.
      final logo = config.resolve(
        '/mobile/v1/metadata/9/logo/?v=societe-3f2a9c1b7d4e',
      );
      expect(
        logo.toString(),
        'http://10.10.10.53:8222/mobile/v1/metadata/9/logo/?v=societe-3f2a9c1b7d4e',
      );
      expect(config.isApiOrigin(logo), isTrue);
      expect(config.isApiOrigin(Uri.parse('http://10.10.10.54:8222/x')), isFalse);
      expect(config.isApiOrigin(Uri.parse('http://10.10.10.53/x')), isFalse);
    });
  });

  test('version comparison (force update)', () {
    expect(isVersionLower('2.2', '3.0.0'), isTrue);
    expect(isVersionLower('3.0.0', '3.0.0'), isFalse);
    expect(isVersionLower('3.0.1', '3.0.0'), isFalse);
    expect(isVersionLower('3.0.0+7', '3.0.1'), isTrue);
    expect(isVersionLower('3.10.0', '3.9.9'), isFalse);
  });

  test('NTLM user string', () {
    expect(
      const PbiCredentials(domain: 'GSH', username: 'H0017549').ntlmUser,
      r'GSH\H0017549',
    );
    expect(PbiCredentials.parse(r'GSH\H1').domain, 'GSH');
    expect(PbiCredentials.parse('H1').ntlmUser, 'H1');
  });

  test('history line and relative time formats', () {
    final d = DateTime(2026, 9, 29, 8, 5);
    expect(formatHistoryLine(d, 184), '29/09/2026  08:05   00:03:04');
    final now = DateTime(2026, 9, 29, 12);
    expect(relativeTimeFr(now.subtract(const Duration(minutes: 3)), now: now), '3mn');
    expect(relativeTimeFr(now.subtract(const Duration(hours: 2)), now: now), '2h');
    expect(relativeTimeFr(now.subtract(const Duration(days: 1)), now: now), '1j');
  });
}
