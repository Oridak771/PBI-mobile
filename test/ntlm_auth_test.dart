import 'package:cbi_mobile/features/viewer/ntlm_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hosts = ['10.20.10.63', 'PBIRS.gsh.local'];

  group('isAllowedPbiHost', () {
    test('matches catalog hosts case-insensitively', () {
      expect(isAllowedPbiHost('10.20.10.63', hosts), isTrue);
      expect(isAllowedPbiHost('pbirs.GSH.local', hosts), isTrue);
      expect(isAllowedPbiHost('pbirs.gsh.local.', hosts), isTrue);
      expect(isAllowedPbiHost('10.20.10.63:80', hosts), isTrue);
    });

    test('rejects unknown hosts and look-alikes', () {
      expect(isAllowedPbiHost('10.20.10.64', hosts), isFalse);
      expect(isAllowedPbiHost('evil.pbirs.gsh.local', hosts), isFalse);
      expect(isAllowedPbiHost('pbirs.gsh.local.evil.com', hosts), isFalse);
      expect(isAllowedPbiHost('', hosts), isFalse);
      expect(isAllowedPbiHost('10.20.10.63', const []), isFalse);
    });
  });

  group('decideHttpAuth', () {
    test('first challenge on a known host uses the stored password', () {
      expect(
        decideHttpAuth(
          host: '10.20.10.63',
          allowedHosts: hosts,
          previousAttempts: 0,
          hasStoredPassword: true,
        ),
        HttpAuthDecision.useStoredCredentials,
      );
    });

    test('a repeated challenge asks the user', () {
      expect(
        decideHttpAuth(
          host: '10.20.10.63',
          allowedHosts: hosts,
          previousAttempts: 1,
          hasStoredPassword: true,
        ),
        HttpAuthDecision.askUser,
      );
    });

    test('no stored password asks the user', () {
      expect(
        decideHttpAuth(
          host: '10.20.10.63',
          allowedHosts: hosts,
          previousAttempts: 0,
          hasStoredPassword: false,
        ),
        HttpAuthDecision.askUser,
      );
    });

    test('unknown host is always cancelled', () {
      for (final attempts in [0, 1, 5]) {
        expect(
          decideHttpAuth(
            host: 'login.example.com',
            allowedHosts: hosts,
            previousAttempts: attempts,
            hasStoredPassword: true,
          ),
          HttpAuthDecision.cancel,
        );
      }
    });
  });

  test('tracker counts challenges per host and resets', () {
    final tracker = NtlmChallengeTracker(hosts);
    expect(
      tracker.next('10.20.10.63', hasStoredPassword: true),
      HttpAuthDecision.useStoredCredentials,
    );
    expect(
      tracker.next('PBIRS.gsh.local', hasStoredPassword: true),
      HttpAuthDecision.useStoredCredentials,
      reason: 'other host has its own counter',
    );
    expect(
      tracker.next('10.20.10.63', hasStoredPassword: true),
      HttpAuthDecision.askUser,
    );
    expect(
      tracker.next('unknown.host', hasStoredPassword: true),
      HttpAuthDecision.cancel,
    );
    tracker.reset();
    expect(
      tracker.next('10.20.10.63', hasStoredPassword: true),
      HttpAuthDecision.useStoredCredentials,
    );
  });
}
