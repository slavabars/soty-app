import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/settings_dao.dart';
import 'package:dtm_app/features/settings/app_lock_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBiometricAuth implements BiometricAuth {
  bool supported;
  bool result;
  int authenticateCalls = 0;
  String? lastReason;

  FakeBiometricAuth({this.supported = true, this.result = true});

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCalls++;
    lastReason = reason;
    return result;
  }
}

void main() {
  late AppDatabase db;
  late SettingsDao dao;
  late FakeBiometricAuth biometric;
  late AppLockController lock;

  final sweet = 'correct-horse';
  const samples = 1000;

  setUp(() {
    db = AppDatabase.inMemory();
    dao = SettingsDao(db);
    biometric = FakeBiometricAuth();
    lock = AppLockController(dao, biometric: biometric, iterations: samples);
  });

  tearDown(() async {
    await db.close();
  });

  AppLockController fresh({BiometricAuth? biometrics}) =>
      AppLockController(
        dao,
        biometric: biometrics ?? const UnavailableBiometricAuth(),
        iterations: samples,
      );

  test('starts disabled with no verifier', () async {
    await lock.load();
    expect(lock.isEnabled, isFalse);
    expect(lock.isBiometricEnabled, isFalse);
    expect(await lock.verify(sweet), isFalse);
  });

  test('setting a password enables the lock and verifies only the value',
      () async {
    await lock.load();
    await lock.setPassword(sweet);
    expect(lock.isEnabled, isTrue);
    expect(await lock.verify(sweet), isTrue);
    expect(await lock.verify('wrong-password'), isFalse);
  });

  test('a corrupt verifier is dropped so the app still boots unlocked',
      () async {
    await dao.set('app_lock_password', 'pbkdf2-sha256|not-a-number|aa|bb');
    await dao.set('app_lock_biometric', '1');

    await lock.load();

    expect(lock.isEnabled, isFalse);
    expect(lock.isBiometricEnabled, isFalse);
    expect(lock.recoveredFromCorruptVerifier, isTrue);
    // The bad row is gone, so the next launch does not repeat the warning.
    expect(await dao.get('app_lock_password'), isNull);
    expect(await dao.get('app_lock_biometric'), isNull);

    await lock.setPassword(sweet);
    expect(lock.recoveredFromCorruptVerifier, isFalse);
    expect(await lock.verify(sweet), isTrue);
  });

  test('a valid verifier never reports a recovery', () async {
    await lock.setPassword(sweet);
    final reloaded = fresh();
    await reloaded.load();
    expect(reloaded.isEnabled, isTrue);
    expect(reloaded.recoveredFromCorruptVerifier, isFalse);
    expect(await reloaded.verify(sweet), isTrue);
  });

  test('every setPassword uses a fresh salt (distinct stored verifiers)',
      () async {
    await lock.setPassword(sweet);
    final first = await dao.get('app_lock_password');
    await lock.setPassword(sweet);
    final second = await dao.get('app_lock_password');
    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first, isNot(second));
  });

  test('password bounds are enforced', () async {
    await lock.load();
    await expectLater(lock.setPassword('12345'), throwsArgumentError);
    await expectLater(lock.setPassword('x' * 129), throwsArgumentError);
    expect(lock.isEnabled, isFalse);
    await lock.setPassword(sweet);
    expect(await lock.verify('12345'), isFalse);
    expect(await lock.verify('x' * 129), isFalse);
  });

  test('disable requires the current password and clears biometrics',
      () async {
    await lock.load();
    await lock.setPassword(sweet);
    await lock.setBiometricEnabled(enabled: true, confirmPassword: sweet);
    expect(await lock.disable('not-it'), isFalse);
    expect(lock.isEnabled, isTrue);
    expect(await lock.disable(sweet), isTrue);
    expect(lock.isEnabled, isFalse);
    expect(lock.isBiometricEnabled, isFalse);
    expect(await dao.get('app_lock_password'), isNull);
    expect(await dao.get('app_lock_biometric'), isNull);
  });

  test('changePassword swaps the verifier', () async {
    await lock.load();
    await lock.setPassword(sweet);
    await expectLater(
      lock.changePassword(current: 'nope', next: sweet),
      throwsArgumentError,
    );
    await lock.changePassword(current: sweet, next: 'new-password');
    expect(await lock.verify(sweet), isFalse);
    expect(await lock.verify('new-password'), isTrue);
  });

  test('biometric flag needs a verifier and password confirmation', () async {
    await lock.load();
    await expectLater(
      lock.setBiometricEnabled(enabled: true, confirmPassword: sweet),
      throwsStateError,
    );
    await lock.setPassword(sweet);
    await expectLater(
      lock.setBiometricEnabled(enabled: true, confirmPassword: 'nope'),
      throwsArgumentError,
    );
    await lock.setBiometricEnabled(enabled: true, confirmPassword: sweet);
    expect(lock.isBiometricEnabled, isTrue);
    await lock.setBiometricEnabled(enabled: false);
    expect(lock.isBiometricEnabled, isFalse);
  });

  test('biometric unlock authenticates only when enabled', () async {
    await lock.load();
    await lock.setPassword(sweet);
    expect(await lock.unlockWithBiometric(reason: 'Unlock'), isFalse);
    expect(biometric.authenticateCalls, 0);

    await lock.setBiometricEnabled(enabled: true, confirmPassword: sweet);
    biometric.result = true;
    expect(await lock.unlockWithBiometric(reason: 'Unlock Soty'), isTrue);
    expect(biometric.authenticateCalls, 1);
    expect(biometric.lastReason, 'Unlock Soty');

    biometric.result = false;
    expect(await lock.unlockWithBiometric(reason: 'Unlock Soty'), isFalse);
  });

  test('unlock does not authenticate when biometrics unsupported', () async {
    await lock.load();
    await lock.setPassword(sweet);
    await lock.setBiometricEnabled(enabled: true, confirmPassword: sweet);
    biometric.supported = false;
    biometric.result = false;
    expect(await lock.unlockWithBiometric(reason: 'x'), isFalse);
  });

  test('disabled lock never authenticates', () async {
    biometric.result = true;
    await lock.load();
    expect(await lock.unlockWithBiometric(reason: 'x'), isFalse);
    expect(biometric.authenticateCalls, 0);
  });

  test('state persists across controller instances', () async {
    await lock.load();
    await lock.setPassword(sweet);
    await lock.setBiometricEnabled(enabled: true, confirmPassword: sweet);

    final reloaded = fresh();
    await reloaded.load();
    expect(reloaded.isEnabled, isTrue);
    expect(reloaded.isBiometricEnabled, isTrue);
    expect(await reloaded.verify(sweet), isTrue);
    expect(await reloaded.verify('nope'), isFalse);
  });

  test('a tampered verifier makes the lock recover, not crash', () async {
    await dao.set('app_lock_password', 'pbkdf2-sha256|garbage');
    final tampered = fresh();
    await tampered.load();
    expect(tampered.isEnabled, isFalse);
    expect(tampered.recoveredFromCorruptVerifier, isTrue);
  });

  test('altered verifier bytes are dropped instead of bricking the app',
      () async {
    await lock.setPassword(sweet);
    final record = await dao.get('app_lock_password');
    final flipped = record!.substring(0, record.length - 2) +
        (record.codeUnitAt(record.length - 1) == 48 ? '1' : '0');
    await dao.set('app_lock_password', flipped);
    final tampered = fresh();
    await tampered.load();
    expect(tampered.isEnabled, isFalse);
    expect(tampered.recoveredFromCorruptVerifier, isTrue);
    expect(await dao.get('app_lock_password'), isNull);
  });
}