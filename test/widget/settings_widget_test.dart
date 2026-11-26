import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dtm_app/core/build_info.dart';
import 'package:dtm_app/core/crypto/identity_claim.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/host/host_link.dart';
import 'package:dtm_app/core/i18n/app_prefs.dart';
import 'package:dtm_app/core/i18n/soty_l10n.dart';
import 'package:dtm_app/core/notifications/notification_service.dart';
import 'package:dtm_app/core/security_limits.dart';
import 'package:dtm_app/core/storage/conversation_dao.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/identity_dao.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/core/storage/peer_dao.dart';
import 'package:dtm_app/core/storage/pruned_roots_dao.dart';
import 'package:dtm_app/core/storage/settings_dao.dart';
import 'package:dtm_app/core/sync/envelope_processor.dart';
import 'package:dtm_app/core/transport/host/host_transport.dart'
    show HostTransport, RelayMode;
import 'package:dtm_app/core/transport/mesh/mesh_transport.dart';
import 'package:dtm_app/core/transport/p2p/p2p_transport.dart';
import 'package:dtm_app/core/transport/transport.dart';
import 'package:dtm_app/core/update/update_client.dart';
import 'package:dtm_app/core/update/update_controller.dart';
import 'package:dtm_app/features/identity/identity_controller.dart';
import 'package:dtm_app/features/messenger/messenger_controller.dart';
import 'package:dtm_app/features/settings/app_lock_controller.dart';
import 'package:dtm_app/features/settings/lock_screen.dart';
import 'package:dtm_app/features/settings/settings_screen.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

import 'update_fixture.dart';

/// Same-isolate derivation for widget tests: isolates do not signal under
/// flutter_test's FakeAsync zone, so [AppLockController] derives inline here.
Future<Uint8List> fakeDeriver(
  String password,
  Uint8List salt,
  int iterations,
) async {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, iterations, appLockHashBytes));
  return derivator.process(utf8.encode(password));
}

class FakeNotifications implements NotificationService {
  FakeNotifications();

  NotificationAvailability state = NotificationAvailability.ready;
  NotificationTestResult result = NotificationTestResult.sent;
  String error = '';
  int tests = 0;
  int opens = 0;
  bool canOpenSettings = false;
  final StreamController<String> _taps =
      StreamController<String>.broadcast();

  @override
  bool get canOpenSystemSettings => canOpenSettings;

  @override
  Stream<String> get onNotificationTap => _taps.stream;

  @override
  Future<void> initialize({String? actionLabel}) async {}

  @override
  Future<void> showChatMessage({
    required String peerPubKey,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancelChatMessage(String peerPubKey) async {}

  @override
  Future<NotificationAvailability> availability() async => state;

  @override
  Future<NotificationTestResult> sendTest({
    required String title,
    required String body,
  }) async {
    tests++;
    return result;
  }

  @override
  String get lastError => error;

  @override
  Future<void> openSystemSettings() async {
    opens++;
    state = NotificationAvailability.ready;
  }

  @override
  Future<void> dispose() async => _taps.close();
}

class _FailingFeed implements ReleaseFeed {
  @override
  Future<String?> fetchTagNotes(String version) async => null;

  @override
  Future<UpdateRelease?> fetchLatest() async =>
      throw const UpdateCheckException('offline');

  @override
  Future<int> download(
    UpdateRelease release,
    File target, {
    void Function(double? progress)? onProgress,
  }) async => throw const UpdateCheckException('offline');
}

class WidgetBiometric implements BiometricAuth {
  bool supported;
  bool result;

  WidgetBiometric({this.supported = true, this.result = true});

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> authenticate({required String reason}) async => result;
}

class SpyTransport implements Transport, PeerImportable {
  final List<DtmPeer> imported = [];
  final StreamController<DtmPeer> _peers =
      StreamController<DtmPeer>.broadcast();

  @override
  String get name => 'spy';

  @override
  bool get isRunning => false;

  @override
  Stream<DtmPeer> get peers => _peers.stream;

  /// Pushes a presence/peer update, like a real transport would.
  void emit(DtmPeer peer) => _peers.add(peer);

  @override
  void setEnvelopeSink(EnvelopeSink sink) {}

  @override
  Future<void> start({
    required String myEdPubKey,
    required String myXPubKey,
    required String displayName,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> send(Envelope envelope, {bool directOnly = false}) async => true;

  @override
  void importPeer(DtmPeer peer) => imported.add(peer);
}

Future<AppLockController> lockedController(
  AppDatabase db, {
  required WidgetBiometric biometric,
  String? password,
  bool biometricOn = false,
}) async {
  final lock = AppLockController(
    SettingsDao(db),
    biometric: biometric,
    iterations: 1000,
    deriver: fakeDeriver,
  );
  await lock.load();
  final pw = password;
  if (pw != null) {
    await lock.setPassword(pw);
    if (biometricOn) {
      await lock.setBiometricEnabled(enabled: true, confirmPassword: pw);
    }
  }
  return lock;
}

/// These tests never download, so a path that is not touched avoids real
/// filesystem I/O, which cannot complete inside `testWidgets`' fake clock.
final Directory _noCache = Directory('/tmp/soty-update-test');

void main() {
  group('LockScreen', () {
    testWidgets('wrong then right password unlock', (tester) async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final biometric = WidgetBiometric(supported: false);
      final lock = await lockedController(db, biometric: biometric);
      await lock.setPassword('secret123');

      var unlocked = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LockScreen(appLock: lock, onUnlocked: () => unlocked++),
        ),
      );

      await tester.enterText(find.byType(TextField), 'wrong-pass');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.text('Incorrect password'), findsOneWidget);
      expect(unlocked, 0);

      await tester.enterText(find.byType(TextField), 'secret123');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(unlocked, 1);
    });

    testWidgets('biometric prompt unlocks without a password', (tester) async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final biometric = WidgetBiometric(supported: true, result: true);
      final lock = await lockedController(
        db,
        biometric: biometric,
        password: 'secret123',
        biometricOn: true,
      );
      expect(lock.lastBiometricUnlockAt, isNull);

      var unlocked = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LockScreen(appLock: lock, onUnlocked: () => unlocked++),
        ),
      );
      await tester.pumpAndSettle();
      expect(unlocked, 1);
      expect(lock.lastBiometricUnlockAt, isNotNull);
    });

    testWidgets('failed biometric keeps the lock', (tester) async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final biometric = WidgetBiometric(supported: true, result: false);
      final lock = await lockedController(
        db,
        biometric: biometric,
        password: 'secret123',
        biometricOn: true,
      );

      var unlocked = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LockScreen(appLock: lock, onUnlocked: () => unlocked++),
        ),
      );
      await tester.pumpAndSettle();
      expect(unlocked, 0);
      expect(find.text('Soty is locked'), findsOneWidget);
      expect(lock.lastBiometricUnlockAt, isNull);
    });
  });

  group('SettingsScreen app lock', () {
    late AppDatabase db;
    late IdentityController identity;
    late MessengerController messenger;
    late AppLockController lock;
    late WidgetBiometric biometric;

    setUp(() async {
      db = AppDatabase.inMemory();
      final dao = MessageDao(db);
      final rootsDao = PrunedRootsDao(db);
      final keyPair = await DtmKeyPair.generate();
      identity = IdentityController(IdentityDao(db));
      await identity.createNew(displayName: 'Test');
      final processor = EnvelopeProcessor(identity: keyPair, dao: dao);
      messenger = MessengerController(
        processor: processor,
        dao: dao,
        prunedRootsDao: rootsDao,
        peerDao: PeerDao(db),
        conversationDao: ConversationDao(db),
        identity: keyPair,
        transports: const <Transport>[],
        storeOutgoing: () => false,
      );
      await messenger.init();
      biometric = WidgetBiometric(supported: true, result: true);
      lock = await lockedController(db, biometric: biometric);
    });

    tearDown(() async {
      await messenger.dispose();
      await db.close();
    });

    Future<void> pumpSettings(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            identity: identity,
            messenger: messenger,
            appLock: lock,
            prefs: AppPrefs(),
          ),
        ),
      );
    }

    testWidgets('enabling the lock requires a new password', (tester) async {
      await pumpSettings(tester);
      expect(lock.isEnabled, isFalse);
      expect(find.text('My QR code'), findsOneWidget);

      await tester.tap(find.text('App lock'));
      await tester.pumpAndSettle();
      expect(find.text('Set app lock password'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'secret123');
      await tester.enterText(find.byType(TextField).at(1), 'secret123');
      await tester.tap(find.text('Enable lock'));
      await tester.pumpAndSettle();

      expect(lock.isEnabled, isTrue);
      expect(await lock.verify('secret123'), isTrue);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Fingerprint unlock'), findsOneWidget);
    });

    testWidgets('mismatched passwords do not enable the lock', (tester) async {
      await pumpSettings(tester);
      await tester.tap(find.text('App lock'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'secret123');
      await tester.enterText(find.byType(TextField).at(1), 'different');
      await tester.tap(find.text('Enable lock'));
      await tester.pump();
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(lock.isEnabled, isFalse);
    });

    testWidgets('the about card opens the published legal pages',
        (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            identity: identity,
            messenger: messenger,
            appLock: lock,
            prefs: AppPrefs(),
            legalOpener: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('privacyRow')),
        300,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('privacyRow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('privacyRow')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('termsRow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('termsRow')));
      await tester.pumpAndSettle();

      expect(
        opened.map((uri) => uri.toString()),
        ['https://soty.su/en/privacy', 'https://soty.su/en/terms'],
      );
    });

    testWidgets('send-on-enter toggle flips and persists the preference',
        (tester) async {
      final prefs = AppPrefs();
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            identity: identity,
            messenger: messenger,
            appLock: lock,
            prefs: prefs,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Send with Enter'), 300);

      expect(prefs.sendOnEnter, isTrue);

      await tester.tap(find.text('Send with Enter'));
      await tester.pumpAndSettle();

      expect(prefs.sendOnEnter, isFalse);
      expect(find.text('Send with Enter'), findsOneWidget);
    });

    testWidgets('read-receipts toggle flips the preference', (tester) async {
      final prefs = AppPrefs();
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            identity: identity,
            messenger: messenger,
            appLock: lock,
            prefs: prefs,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Read receipts'), 300);
      await tester.pumpAndSettle();

      expect(prefs.readReceipts, isTrue);

      await tester.tap(find.text('Read receipts'));
      await tester.pumpAndSettle();

      expect(prefs.readReceipts, isFalse);
      expect(find.text('Read receipts'), findsOneWidget);
    });

    testWidgets('no update row without a controller (play build)',
        (tester) async {
      await pumpSettings(tester);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Source and releases'), 300);
      await tester.pumpAndSettle();

      expect(find.text('Check for updates'), findsNothing);
      expect(find.byKey(const ValueKey('updateRow')), findsNothing);
    });

    testWidgets('update row appears when the controller is wired',
        (tester) async {
      final update = UpdateController(
        client: FakeFeed(fakeRelease('9.9.9')),
        settings: SettingsDao(db),
      );
      await update.load();
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            identity: identity,
            messenger: messenger,
            appLock: lock,
            prefs: AppPrefs(),
            update: update,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Source and releases'), 300);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('updateRow')), findsOneWidget);
    });

    testWidgets('disabling requires the current password', (tester) async {
      await lock.setPassword('secret123');
      await pumpSettings(tester);
      expect(lock.isEnabled, isTrue);

      await tester.tap(find.text('App lock'));
      await tester.pumpAndSettle();
      expect(find.text('Disable app lock'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'nope');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(lock.isEnabled, isTrue);
      expect(find.text('Incorrect password'), findsOneWidget);

      await tester.tap(find.text('App lock'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'secret123');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(lock.isEnabled, isFalse);
    });

    testWidgets('enabling biometrics flips the switch on screen',
        (tester) async {
      await lock.setPassword('secret123');
      await pumpSettings(tester);
      expect(lock.isEnabled, isTrue);

      await tester.scrollUntilVisible(find.text('Fingerprint unlock'), 200);
      await tester.pumpAndSettle();

      SwitchListTile fingerSwitch() => tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Fingerprint unlock'),
      );
      expect(fingerSwitch().value, isFalse);

      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Fingerprint unlock'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'secret123');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(lock.isBiometricEnabled, isTrue);
      expect(fingerSwitch().value, isTrue);

      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Fingerprint unlock'),
      );
      await tester.pumpAndSettle();
      expect(lock.isBiometricEnabled, isFalse);
      expect(fingerSwitch().value, isFalse);
    });

    testWidgets('relay failover switches between manual and auto mode',
        (tester) async {
      final prefs = AppPrefs();
      await prefs.setRelayMode(RelayMode.auto);
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            identity: identity,
            messenger: messenger,
            appLock: lock,
            prefs: prefs,
          ),
        ),
      );
      expect(prefs.relayMode, RelayMode.auto);

      await tester.scrollUntilVisible(find.text('Relay failover'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Relay failover'));
      await tester.pumpAndSettle();

      expect(find.text('Only configured relays'), findsOneWidget);
      expect(find.text('Automatic fallback'), findsNWidgets(2));

      await tester.tap(find.text('Only configured relays'));
      await tester.pumpAndSettle();

      expect(prefs.relayMode, RelayMode.manual);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            identity: identity,
            messenger: messenger,
            appLock: lock,
            prefs: prefs,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Relay failover'), 300);
      expect(find.text('Only configured relays'), findsOneWidget);
    });

    testWidgets('enabling biometrics with a wrong password shows a snackbar',
        (tester) async {
      await lock.setPassword('secret123');
      await pumpSettings(tester);

      await tester.scrollUntilVisible(find.text('Fingerprint unlock'), 200);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Fingerprint unlock'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(lock.isBiometricEnabled, isFalse);
      expect(find.text('Incorrect password'), findsOneWidget);
    });
  });

  group('SettingsScreen appearance', () {
    late AppDatabase db;
    late AppLockController lock;
    late AppPrefs prefs;
    late MessengerController messenger;

    setUp(() async {
      db = AppDatabase.inMemory();
      prefs = AppPrefs()..attach(SettingsDao(db));
      lock = await lockedController(
        db,
        biometric: WidgetBiometric(supported: false),
      );
    });

    tearDown(() => db.close());

    Future<void> pumpSettings(
      WidgetTester tester, {
      MeshTransport? meshTransport,
    }) async {
      final keyPair = await DtmKeyPair.generate();
      final identity = IdentityController(IdentityDao(db));
      await identity.createNew(displayName: 'Test');
      final dao = MessageDao(db);
      final processor = EnvelopeProcessor(identity: keyPair, dao: dao);
      messenger = MessengerController(
        processor: processor,
        dao: dao,
        peerDao: PeerDao(db),
        conversationDao: ConversationDao(db),
        prunedRootsDao: PrunedRootsDao(db),
        identity: keyPair,
        transports: const <Transport>[],
        storeOutgoing: () => false,
      );
      await messenger.init();
      addTearDown(messenger.dispose);
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: prefs,
          builder: (context, _) => MaterialApp(
            builder: (context, child) => SotyL10n(
              locale: prefs.locale,
              child: child ?? const SizedBox.shrink(),
            ),
            home: SettingsScreen(
              identity: identity,
              messenger: messenger,
              appLock: lock,
              prefs: prefs,
              meshTransport: meshTransport,
            ),
          ),
        ),
      );
    }

Future<void> pumpTallSettings(
      WidgetTester tester, {
      MeshTransport? meshTransport,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await pumpSettings(tester, meshTransport: meshTransport);
    }

    testWidgets('the mesh tile says a radio that never started is off',
        (tester) async {
      final meshTransport = MeshTransport();
      addTearDown(meshTransport.dispose);

      await pumpTallSettings(tester, meshTransport: meshTransport);
      await tester.scrollUntilVisible(
        find.text('Mesh (BLE/Wi-Fi Direct)'),
        300,
      );
      await tester.pumpAndSettle();

      expect(find.text('Mesh (BLE/Wi-Fi Direct)'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
    });

    testWidgets('the mesh tile reports no transport at all', (tester) async {
      await pumpTallSettings(tester);
      await tester.scrollUntilVisible(
        find.text('Mesh (BLE/Wi-Fi Direct)'),
        300,
      );
      await tester.pumpAndSettle();

      expect(find.text('Mesh (BLE/Wi-Fi Direct)'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
    });

    testWidgets('switching the language to Russian renders ru',
        (tester) async {
      await pumpTallSettings(tester);
      expect(find.text('Settings'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Language'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('English'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Русский'),
        ),
      );
      await tester.pumpAndSettle();

      expect(prefs.locale, const Locale('ru'));
      expect(await SettingsDao(db).get(AppPrefs.localeKey), 'ru');
      expect(find.text('Настройки'), findsOneWidget);
    });

    testWidgets('theme picker persists the selection', (tester) async {
      await pumpTallSettings(tester);
      await tester.scrollUntilVisible(find.text('Theme'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('System'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Dark'),
        ),
      );
      await tester.pumpAndSettle();

      expect(prefs.theme, SotyTheme.dark);
      expect(prefs.theme.toThemeMode(), ThemeMode.dark);
      expect(await SettingsDao(db).get(AppPrefs.themeKey), 'dark');
    });

    testWidgets(
      'retention picker persists and re-prunes right away',
      (tester) async {
        final settings = SettingsDao(db);
        await settings.set(retentionSettingsKey, '30');
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpSettings(tester);

        final legacyOwnRow = Envelope(
          id: 'own-legacy-driven',
          senderPubKey: messenger.myEdPubKey,
          recipientPubKey: 'bob-x',
          timestamp: DateTime.now()
                  .toUtc()
                  .millisecondsSinceEpoch -
              const Duration(days: 120).inMilliseconds,
          ciphertext: base64Encode(utf8.encode('old own message')),
          ephemeralPubKey: 'ephemeral',
          signature: 'signature',
        );
        await messenger.dao.insertIfAbsent(legacyOwnRow);

        await tester.scrollUntilVisible(find.text('Keep messages'), 300);
        expect(find.text('30 days'), findsOneWidget);

        await tester.ensureVisible(find.text('Keep messages'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Keep messages'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('90 days'),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('90 days'));
        await tester.pumpAndSettle();

        expect(prefs.retentionDays, 90);
        expect(await settings.get(retentionSettingsKey), '90');
        expect(await messenger.dao.has(legacyOwnRow.id), isFalse);
      },
    );
  });

  group('invite QR contract', () {
    test('invite payload scanning path accepts a fresh claim', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = MessageDao(db);
      final rootsDao = PrunedRootsDao(db);
      final keyPair = await DtmKeyPair.generate();
      final identity = IdentityController(IdentityDao(db));
      await identity.createNew(displayName: 'Alice');

      final remoteKp = await DtmKeyPair.generate();
      final claim = await IdentityClaim.forIdentity(
        identity: remoteKp,
        displayName: 'Bob',
      );

      final processor = EnvelopeProcessor(identity: keyPair, dao: dao);
      final messenger = MessengerController(
        processor: processor,
        dao: dao,
        peerDao: PeerDao(db),
        conversationDao: ConversationDao(db),
        prunedRootsDao: rootsDao,
        identity: keyPair,
        transports: const <Transport>[],
        storeOutgoing: () => false,
      );
      await messenger.init();
      addTearDown(messenger.dispose);

      final ourInvite = await identity.invitePayload();
      expect(ourInvite, isNotNull);
      expect(ourInvite, contains('"displayName":"Alice"'));

      expect(await messenger.importInvite(claim.encode()), isTrue);
      expect(
        messenger.peers[await remoteKp.x25519PublicKeyHex]?.displayName,
        'Bob',
      );
    });
  });
  group('SettingsScreen about and network stats', () {
    late AppDatabase db;
    late IdentityController identity;
    late MessengerController messenger;
    late AppLockController lock;
    late SpyTransport transport;
    late P2PTransport p2p;

    setUp(() async {
      db = AppDatabase.inMemory();
      final dao = MessageDao(db);
      final keyPair = await DtmKeyPair.generate();
      identity = IdentityController(IdentityDao(db));
      await identity.createNew(displayName: 'Test');
      transport = SpyTransport();
      messenger = MessengerController(
        processor: EnvelopeProcessor(identity: keyPair, dao: dao),
        dao: dao,
        prunedRootsDao: PrunedRootsDao(db),
        peerDao: PeerDao(db),
        conversationDao: ConversationDao(db),
        identity: keyPair,
        transports: [transport],
        storeOutgoing: () => false,
      );
      await messenger.init();
      messenger.startListening();
      lock = await lockedController(
        db,
        biometric: WidgetBiometric(supported: true, result: true),
      );
      // Not started: the gauge must then read zero connections against the
      // default budget, which is exactly the "10/25" shape the user asked for.
      p2p = P2PTransport(ed25519SeedHex: List.filled(32, 'ab').join());
    });

    tearDown(() async {
      await messenger.dispose();
      await db.close();
    });

    Future<void> pumpSettings(
      WidgetTester tester, {
      UpdateController? update,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            identity: identity,
            messenger: messenger,
            appLock: lock,
            prefs: AppPrefs(),
            p2pTransport: p2p,
            update: update,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows the built version and the git link', (tester) async {
      await pumpSettings(tester);
      await tester.scrollUntilVisible(find.text('Version'), 300);
      await tester.pumpAndSettle();

      expect(find.text('Version'), findsOneWidget);
      expect(find.text(kSotyVersion), findsOneWidget);
      expect(find.text(kSotyGitUrl), findsOneWidget);
    });

    testWidgets('copies the git link instead of opening a browser',
        (tester) async {
      // The real clipboard channel has no handler under flutter_test, and the
      // write would then never complete; capture what was handed to it.
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<Object?, Object?>;
            copied = args['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpSettings(tester);
      await tester.scrollUntilVisible(find.text('Source and releases'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Source and releases'));
      await tester.pumpAndSettle();

      expect(copied, kSotyGitUrl);
      expect(find.text('Link copied to clipboard'), findsOneWidget);
    });

    testWidgets('counts registered, online and direct connections',
        (tester) async {
      transport.emit(
        DtmPeer(pubKey: 'a' * 64, lastSeen: DateTime.now(), online: true),
      );
      transport.emit(
        DtmPeer(pubKey: 'b' * 64, lastSeen: DateTime.now(), online: false),
      );
      transport.emit(
        DtmPeer(pubKey: 'c' * 64, lastSeen: DateTime.now(), online: true),
      );
      await pumpSettings(tester);
      await tester.scrollUntilVisible(find.text('Peers in network'), 300);
      await tester.pumpAndSettle();

      expect(find.text('3 registered · 2 online'), findsOneWidget);
      expect(
        find.text('0 of $maxActivePeersDefault direct peers in exchange'),
        findsOneWidget,
      );
      expect(find.text('0 visible · 0 connected'), findsOneWidget);
    });

    testWidgets('counts visible and connected relay hosts', (tester) async {
      final hosts = HostTransport(
        settings: SettingsDao(db),
        lastTimestamp: MessageDao(db).latestTimestamp,
      );
      await hosts.addHost(const HostEndpoint(addr: 'ws://127.0.0.1:1/ws'));
      await hosts.addHost(const HostEndpoint(addr: 'ws://127.0.0.1:2/ws'));
      final hostMessenger = MessengerController(
        processor: EnvelopeProcessor(
          identity: await DtmKeyPair.generate(),
          dao: MessageDao(db),
        ),
        dao: MessageDao(db),
        prunedRootsDao: PrunedRootsDao(db),
        peerDao: PeerDao(db),
        conversationDao: ConversationDao(db),
        identity: await DtmKeyPair.generate(),
        transports: [transport, hosts],
        storeOutgoing: () => false,
      );
      addTearDown(hostMessenger.dispose);
      await hostMessenger.init();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            identity: identity,
            messenger: hostMessenger,
            appLock: lock,
            prefs: AppPrefs(),
            p2pTransport: p2p,
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Relay hosts'), 300);
      await tester.pumpAndSettle();

      expect(find.text('2 visible · 0 connected'), findsOneWidget);
    });

    testWidgets('offers the background toggle and the battery row',
        (tester) async {
      await pumpSettings(tester);
      await tester.scrollUntilVisible(find.text('Work in background'), 300);
      await tester.pumpAndSettle();

      expect(find.text('Work in background'), findsOneWidget);
      expect(find.text('Battery optimization'), findsOneWidget);
    });

    testWidgets('a build without an update feed has no update row',
        (tester) async {
      await pumpSettings(tester);
      await tester.scrollUntilVisible(find.text('Version'), 300);
      await tester.pumpAndSettle();

      expect(find.text('Check for updates'), findsNothing);
      expect(find.byKey(const ValueKey('updateIcon')), findsNothing);
    });

    testWidgets('a newer release puts the update icon in the app bar',
        (tester) async {
      final feed = FakeFeed(fakeRelease('9.9.9+99'));
      final update = updateController(feed, SettingsDao(db), _noCache);
      addTearDown(update.dispose);
      await update.check();

      await pumpSettings(tester, update: update);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('updateIcon')), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Check for updates'), 300);
      await tester.pumpAndSettle();
      expect(find.text('Version 9.9.9+99 is available'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('updateIcon')));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('an up-to-date build has no icon but still checks on demand',
        (tester) async {
      final feed = FakeFeed(null);
      final update = updateController(feed, SettingsDao(db), _noCache);
      addTearDown(update.dispose);
      await update.check();

      await pumpSettings(tester, update: update);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('updateIcon')), findsNothing);

      await tester.scrollUntilVisible(find.text('Check for updates'), 300);
      await tester.pumpAndSettle();
      expect(find.text('You have the latest version'), findsOneWidget);
      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
      expect(find.text('You have the latest version'), findsWidgets);
    });

    testWidgets('a failed check says so instead of claiming up to date',
        (tester) async {
      final feed = _FailingFeed();
      final update = updateController(feed, SettingsDao(db), _noCache);
      addTearDown(update.dispose);
      await update.check();

      await pumpSettings(tester, update: update);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Check for updates'), 300);
      await tester.pumpAndSettle();
      expect(find.text('Could not check for updates'), findsOneWidget);
    });

    testWidgets('toggling background off persists the choice', (tester) async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      final prefs = AppPrefs()..attach(dao);
      await prefs.load();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            identity: identity,
            messenger: messenger,
            appLock: lock,
            prefs: prefs,
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Work in background'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work in background'));
      await tester.pumpAndSettle();

      expect(prefs.background, isFalse);
      expect(await dao.get(AppPrefs.backgroundKey), 'false');
    });
  });
  group('SettingsScreen notifications', () {
    late AppDatabase db;
    late IdentityController identity;
    late MessengerController messenger;
    late AppLockController lock;
    late FakeNotifications notifications;

    setUp(() async {
      db = AppDatabase.inMemory();
      final dao = MessageDao(db);
      final keyPair = await DtmKeyPair.generate();
      identity = IdentityController(IdentityDao(db));
      await identity.createNew(displayName: 'Test');
      messenger = MessengerController(
        processor: EnvelopeProcessor(identity: keyPair, dao: dao),
        dao: dao,
        prunedRootsDao: PrunedRootsDao(db),
        peerDao: PeerDao(db),
        conversationDao: ConversationDao(db),
        identity: keyPair,
        transports: const <Transport>[],
        storeOutgoing: () => false,
      );
      await messenger.init();
      lock = await lockedController(
        db,
        biometric: WidgetBiometric(supported: true, result: true),
      );
      notifications = FakeNotifications();
    });

    tearDown(() async {
      await messenger.dispose();
      await db.close();
    });

    Future<void> pumpNotifications(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              SotyL10n(locale: locale, child: child!),
          home: SettingsScreen(
            identity: identity,
            messenger: messenger,
            appLock: lock,
            prefs: AppPrefs(),
            notifications: notifications,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> scrollToSection(WidgetTester tester, String label) async {
      await tester.scrollUntilVisible(find.text('Message notifications'), 300);
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
    }

    testWidgets('a working notifier is reported as enabled', (tester) async {
      await pumpNotifications(tester);
      await scrollToSection(tester, 'Enabled on this device');

      // No dead end offered when there is nothing to fix.
      expect(
        find.text('Open system notification settings'),
        findsNothing,
      );
    });

    testWidgets('a system that blocks notifications offers the way out',
        (tester) async {
      notifications
        ..state = NotificationAvailability.blocked
        ..canOpenSettings = true;
      await pumpNotifications(tester);
      await scrollToSection(tester, 'Blocked by the system');

      await tester.tap(find.text('Open system notification settings'));
      await tester.pumpAndSettle();

      expect(notifications.opens, 1);
      await scrollToSection(tester, 'Enabled on this device');
    });

    testWidgets('a platform without a settings screen is not sent to one',
        (tester) async {
      notifications.state = NotificationAvailability.blocked;
      await pumpNotifications(tester);
      await scrollToSection(tester, 'Blocked by the system');

      // A Linux desktop has no per-app notification screen, so a button that
      // cannot open anything is worse than no button.
      expect(
        find.text('Open system notification settings'),
        findsNothing,
      );
    });

    testWidgets('a notifier that refused to start shows its reason',
        (tester) async {
      notifications
        ..state = NotificationAvailability.unavailable
        ..error = 'no channel';
      await pumpNotifications(tester);
      await scrollToSection(tester, 'Not available: no channel');
    });

    testWidgets('a test banner reports back', (tester) async {
      await pumpNotifications(tester);
      await tester.scrollUntilVisible(
        find.text('Send test notification'),
        300,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send test notification'));
      await tester.pumpAndSettle();

      expect(notifications.tests, 1);
      expect(find.text('Test notification sent'), findsOneWidget);
    });

    testWidgets('a blocked system is not offered a test it will drop',
        (tester) async {
      notifications
        ..state = NotificationAvailability.blocked
        ..result = NotificationTestResult.blocked;
      await pumpNotifications(tester);
      await tester.scrollUntilVisible(
        find.text('Send test notification'),
        300,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send test notification'));
      await tester.pumpAndSettle();

      expect(find.text('Notifications are blocked by the system'),
          findsOneWidget);
    });

    testWidgets('a failed test shows the platform reason', (tester) async {
      notifications
        ..state = NotificationAvailability.unavailable
        ..result = NotificationTestResult.unavailable
        ..error = 'rejected';
      await pumpNotifications(tester);
      await tester.scrollUntilVisible(
        find.text('Send test notification'),
        300,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send test notification'));
      await tester.pumpAndSettle();

      expect(find.text('Test notification failed: rejected'), findsOneWidget);
    });

    testWidgets('a build without a notifier says so', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            identity: identity,
            messenger: messenger,
            appLock: lock,
            prefs: AppPrefs(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await scrollToSection(tester, 'Not supported on this platform');
    });

    testWidgets('the section is localized', (tester) async {
      await pumpNotifications(tester, locale: const Locale('ru'));
      await tester.scrollUntilVisible(
        find.text('Отправить тестовое уведомление'),
        300,
      );
      await tester.pumpAndSettle();

      expect(find.text('Отправить тестовое уведомление'), findsOneWidget);
      expect(find.text('Включены на этом устройстве'), findsOneWidget);
    });
  });
}
