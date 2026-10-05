import 'package:cbi_mobile/core/storage/lock_settings_store.dart';
import 'package:cbi_mobile/core/storage/remembered_credentials_store.dart';
import 'package:cbi_mobile/core/storage/session_store.dart';
import 'package:cbi_mobile/data/models/user.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('SecureRememberedCredentialsStore', () {
    test('survives the session wipe of logout / 401', () async {
      final session = SecureSessionStore();
      final remembered = SecureRememberedCredentialsStore();
      await session.save(
        const StoredSession(
          token: 't',
          user: User(id: 1, username: 'H0017549', name: 'Mohammed'),
          credentials: PbiCredentials(domain: 'GSH', username: 'H0017549'),
          password: 'secret',
        ),
      );
      await remembered.save('H0017549', 'secret');

      await session.clear(); // logout / 401

      expect(await session.read(), isNull);
      final saved = await remembered.read();
      expect(saved?.username, 'H0017549');
      expect(saved?.password, 'secret');
      expect(saved?.hasPassword, isTrue);
    });

    test('password changed: drops the password, keeps the username', () async {
      final remembered = SecureRememberedCredentialsStore();
      await remembered.save('user@gsh.dz', 'old');
      await remembered.clearPassword();
      final saved = await remembered.read();
      expect(saved?.username, 'user@gsh.dz');
      expect(saved?.password, isNull);
      expect(saved?.hasPassword, isFalse);
    });

    test('clear() forgets everything (login without "Se souvenir de moi")', () async {
      final remembered = SecureRememberedCredentialsStore();
      await remembered.save('H0017549', 'secret');
      await remembered.clear();
      expect(await remembered.read(), isNull);
    });

    test('updatePassword only touches remembered credentials', () async {
      final remembered = SecureRememberedCredentialsStore();
      await remembered.updatePassword('ignored');
      expect(await remembered.read(), isNull);

      await remembered.save('H0017549', 'old');
      await remembered.updatePassword('new');
      expect((await remembered.read())?.password, 'new');

      await remembered.clearPassword();
      await remembered.updatePassword('again');
      expect((await remembered.read())?.password, isNull);
    });
  });

  test('MemoryRememberedCredentialsStore behaves like the secure one', () async {
    final remembered = MemoryRememberedCredentialsStore();
    await remembered.save('u', 'p');
    await remembered.updatePassword('p2');
    expect((await remembered.read())?.password, 'p2');
    await remembered.clearPassword();
    expect((await remembered.read())?.username, 'u');
    expect((await remembered.read())?.password, isNull);
    await remembered.clear();
    expect(await remembered.read(), isNull);
  });

  test('SecureLockSettingsStore round-trips and defaults to off / 1 min', () async {
    final store = SecureLockSettingsStore();
    final initial = await store.load();
    expect(initial.enabled, isFalse);
    expect(initial.delay, LockDelay.oneMinute);
    expect(initial.offered, isFalse);

    await store.save(
      const LockSettings(enabled: true, delay: LockDelay.fifteenMinutes, offered: true),
    );
    final loaded = await store.load();
    expect(loaded.enabled, isTrue);
    expect(loaded.delay, LockDelay.fifteenMinutes);
    expect(loaded.offered, isTrue);

    // The session wipe does not touch the lock settings.
    await SecureSessionStore().clear();
    expect((await store.load()).enabled, isTrue);
  });
}
