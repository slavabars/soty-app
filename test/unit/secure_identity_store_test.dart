import 'package:dtm_app/core/storage/secure_identity_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String _hex(String char) => char * 64;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ru.dcns.soty/secure_identity');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, handler);
  }

  void availableWith(Object? Function() read) {
    answer((call) async {
      switch (call.method) {
        case 'available':
          return true;
        case 'read':
          return read();
      }
      return null;
    });
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('no platform implementation means unavailable', () async {
    messenger.setMockMethodCallHandler(channel, null);
    final store = PlatformSecureIdentityStore(supported: true);
    expect(await store.isAvailable(), isFalse);
  });

  test('a non-Android platform never touches the channel', () async {
    var calls = 0;
    answer((call) async {
      calls++;
      return true;
    });
    final store = PlatformSecureIdentityStore(supported: false);
    expect(await store.isAvailable(), isFalse);
    expect(await store.read(), isNull);
    expect(calls, 0);
  });

  test('read parses a stored pair and lowercases it', () async {
    availableWith(
      () => {'edSeedHex': _hex('A').toLowerCase(), 'xSeedHex': _hex('b')},
    );
    final seeds = await PlatformSecureIdentityStore(supported: true).read();
    expect(seeds!.edSeedHex, _hex('a'));
    expect(seeds.xSeedHex, _hex('b'));
  });

  test('read returns null for an empty store', () async {
    availableWith(() => null);
    expect(await PlatformSecureIdentityStore(supported: true).read(), isNull);
  });

  test('read rejects a malformed seed', () async {
    availableWith(() => {'edSeedHex': 'zz', 'xSeedHex': _hex('b')});
    await expectLater(
      PlatformSecureIdentityStore(supported: true).read(),
      throwsFormatException,
    );
  });

  test('read rejects a payload that is not a map', () async {
    availableWith(() => 'nope');
    await expectLater(
      PlatformSecureIdentityStore(supported: true).read(),
      throwsFormatException,
    );
  });

  test('write sends both seeds to the platform', () async {
    final calls = <MethodCall>[];
    answer((call) async {
      calls.add(call);
      return call.method == 'available' ? true : null;
    });

    await PlatformSecureIdentityStore(supported: true).write(
      SecureSeeds(edSeedHex: _hex('c'), xSeedHex: _hex('d')),
    );

    final write = calls.firstWhere((call) => call.method == 'write');
    expect(write.arguments, {
      'edSeedHex': _hex('c'),
      'xSeedHex': _hex('d'),
    });
  });

  test('write fails without a platform store', () async {
    messenger.setMockMethodCallHandler(channel, null);
    await expectLater(
      PlatformSecureIdentityStore(supported: true).write(
        SecureSeeds(edSeedHex: _hex('c'), xSeedHex: _hex('d')),
      ),
      throwsStateError,
    );
  });

  test('a keystore decryption failure is an identity loss, not a crash',
      () async {
    answer((call) async {
      if (call.method == 'available') return true;
      throw PlatformException(
        code: 'keystore',
        message: 'AEADBadTagException',
      );
    });

    await expectLater(
      PlatformSecureIdentityStore(supported: true).read(),
      throwsA(isA<IdentityUnavailableException>()),
    );
  });

  test('a corrupt store is also reported as an identity loss', () async {
    answer((call) async {
      if (call.method == 'available') return true;
      throw PlatformException(
        code: 'keystore',
        message: 'IllegalStateException',
      );
    });

    await expectLater(
      PlatformSecureIdentityStore(supported: true).read(),
      throwsA(isA<IdentityUnavailableException>()),
    );
  });

  test('other platform failures still surface as platform errors', () async {
    answer((call) async {
      if (call.method == 'available') return true;
      throw PlatformException(code: 'bad_seed', message: 'nope');
    });

    await expectLater(
      PlatformSecureIdentityStore(supported: true).read(),
      throwsA(isA<PlatformException>()),
    );
  });
}
