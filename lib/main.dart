import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import 'core/background/background_service.dart';
import 'core/backup/backup_crypto.dart';
import 'core/backup/backup_service.dart';
import 'core/build_info.dart';
import 'core/channel.dart';
import 'core/crypto/hex.dart';
import 'core/crypto/identity_claim.dart';
import 'core/crypto/keypair.dart';
import 'core/deep_link_inbox.dart';
import 'core/host/host_link.dart';
import 'core/i18n/app_prefs.dart';
import 'core/i18n/soty_l10n.dart';
import 'core/invite_link.dart';
import 'core/net/lan_addrs.dart';
import 'core/net/optional_bind.dart';
import 'core/notifications/chat_notifications.dart';
import 'core/notifications/local_notifications.dart';
import 'core/security_limits.dart';
import 'core/soty_route.dart';
import 'core/storage/conversation_dao.dart';
import 'core/storage/database.dart';
import 'core/storage/identity_dao.dart';
import 'core/storage/identity_reset.dart';
import 'core/storage/media_dao.dart';
import 'core/storage/message_dao.dart';
import 'core/storage/peer_dao.dart';
import 'core/storage/pruned_roots_dao.dart';
import 'core/storage/secure_identity_store.dart';
import 'core/storage/settings_dao.dart';
import 'core/sync/envelope_processor.dart';
import 'core/transport/host/host_transport.dart';
import 'core/transport/mesh/mesh_transport.dart';
import 'core/transport/p2p/p2p_transport.dart';
import 'core/transport/transport.dart';
import 'core/update/update_client.dart';
import 'core/update/update_controller.dart';
import 'features/identity/identity_controller.dart';
import 'features/identity/identity_recovery_screen.dart';
import 'features/identity/identity_screen.dart';
import 'features/identity/onboarding_screen.dart';
import 'features/messenger/chat_screen.dart';
import 'features/messenger/chats_tab.dart';
import 'features/messenger/home_screen.dart';
import 'features/messenger/messenger_controller.dart';
import 'features/settings/app_lock_controller.dart';
import 'features/settings/biometric_auth.dart';
import 'features/settings/lock_screen.dart';
import 'features/settings/settings_screen.dart';
import 'models/message_payload.dart';
import 'models/peer.dart';

/// Baked-in default relay host, always available even when no
/// `SOTY_BOOTSTRAP_HOST` define was set at build time.
const String _defaultRelayHost =
    'soty://host?addr=wss://soty.su/soty-ws'
    '&pk=fad55cc762eda3f6cbc9c6522030ce8ec29e87143c9c78f452038d24143a4e82';

/// Relays that no longer exist. Existing installs keep their persisted host
/// list, so the dead addresses are removed explicitly on the next start.
/// `85.198.75.50` was decommissioned with its server (November 2026) and
/// `77.246.145.113` moved behind TLS on `soty.su`; keep both here until every
/// install from before 1.7.18 has upgraded, then drop the tombstone.
const Set<String> _retiredRelayHosts = <String>{
  'ws://85.198.75.50:3100/ws',
  'ws://77.246.145.113:3100/ws',
};

/// Relay host override; set with
/// `--dart-define=SOTY_BOOTSTRAP_HOST=ws://host:port/ws`.
const String _bootstrapHostDefine = String.fromEnvironment(
  'SOTY_BOOTSTRAP_HOST',
);

final ThemeData _lightTheme = ThemeData(
  colorSchemeSeed: Colors.teal,
  useMaterial3: true,
);

final ThemeData _darkTheme = ThemeData(
  colorSchemeSeed: Colors.teal,
  brightness: Brightness.dark,
  useMaterial3: true,
);

/// Multiaddr advertised to trackers (what peers can dial us at), e.g.
/// `--dart-define=SOTY_ADVERTISE_ADDR=/ip4/10.0.2.2/tcp/5010`.
const String _advertiseAddrDefine = String.fromEnvironment(
  'SOTY_ADVERTISE_ADDR',
);

/// Release feed override for the update check, e.g.
/// `--dart-define=SOTY_UPDATE_URL=http://10.0.2.2:8099/latest`. Empty means
/// the project's own GitHub "latest release" endpoint.
const String _updateUrlDefine = String.fromEnvironment('SOTY_UPDATE_URL');

void main() {
  // A release build must not write to stdout. During a chunked transfer the
  // transport logs several lines per slice; on desktop stdout is a socket
  // nobody drains, and a full buffer blocks the UI isolate. There is nothing
  // a release user can do with those lines anyway.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DtmApp());
}

/// Bootstraps the whole DTM stack. There is no sync server; everything lives
/// on-device and talks directly to peers via mesh + libp2p.
class DtmApp extends StatefulWidget {
  const DtmApp({super.key});

  @override
  State<DtmApp> createState() => _DtmAppState();
}

class _DtmAppState extends State<DtmApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<ChatsTabState> _chatsTabKey = GlobalKey<ChatsTabState>();
  AppDatabase? _db;
  DtmKeyPair? _keyPair;
  IdentityController? _identity;
  MessengerController? _messenger;
  AppLockController? _appLock;
  IdentityClaim? _pendingInvite;
  bool _locked = false;
  bool _needsOnboarding = false;
  String? _pendingChatPeer;
  late final DeepLinkInbox _deepLinks = DeepLinkInbox(
    isLocked: () => _locked,
    onRoute: _applyRoute,
  );
  ChatNotifications? _chatNotifications;
  LocalNotificationService? _notificationService;
  final List<Transport> _transports = [];
  final AppPrefs _prefs = AppPrefs();
  SettingsDao? _settingsDao;
  P2PTransport? _p2pTransport;
  MeshTransport? _meshTransport;
  UpdateController? _update;
  Object? _bootstrapError;

  /// Set when the identity seeds cannot be decrypted (usually a system-backup
  /// restore without the Keystore key). The app then shows the recovery screen
  /// instead of a raw error no user can act on.
  bool _identityUnavailable = false;
  Timer? _pruneTimer;
  Timer? _lanRefreshTimer;
  Timer? _presenceTimer;
  HostTransport? _hostTransport;
  final LanAddrs _lanAddrs = LanAddrs();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pruneTimer?.cancel();
    _lanRefreshTimer?.cancel();
    _presenceTimer?.cancel();
    _update?.dispose();
    unawaited(_chatNotifications?.stop());
    final messenger = _messenger;
    if (messenger != null) {
      unawaited(messenger.dispose());
    }
    for (final transport in _transports) {
      unawaited(transport.stop());
    }
    _db?.close();
    super.dispose();
  }

  /// A `soty://` link delivered to the already-running app (`singleTop` plus
  /// `flutter_deeplinking_enabled` turn a new intent into a pushed route).
  /// The default implementation rebuilds the route from its path only, which
  /// would drop the `soty:` scheme, so the raw URI is used here.
  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    if (isSotyRoute(uri)) {
      await _handleRoute(uri.toString());
      return true;
    }
    return super.didPushRouteInformation(routeInformation);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounded, no chat is on screen even though the widget is still
    // mounted: its messages must stay unread and raise a banner.
    final messenger = _messenger;
    if (messenger != null) {
      unawaited(messenger.setForeground(state == AppLifecycleState.resumed));
    }
    if (state == AppLifecycleState.resumed) {
      // The phone may have switched Wi-Fi while backgrounded: re-enumerate
      // the LAN addresses and push the new set to the relays.
      unawaited(_refreshLanAddrs());
      // And refresh who is actually online now, instead of waiting for the
      // next message to reveal it.
      final p2p = _p2pTransport;
      if (p2p != null) unawaited(p2p.refreshPresence());
      // Coming back is a natural moment to notice a release; the daily gate
      // inside the controller keeps it to one request per day.
      final update = _update;
      if (update != null) unawaited(update.checkIfDue());
    }
    final appLock = _appLock;
    if (state != AppLifecycleState.resumed ||
        appLock == null ||
        !appLock.isEnabled ||
        _locked ||
        _messenger == null) {
      return;
    }
    final lastBio = appLock.lastBiometricUnlockAt;
    final justUnlocked =
        lastBio != null &&
        DateTime.now().difference(lastBio).inMilliseconds <
            biometricResumeLockGraceMs;
    if (justUnlocked) return;
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    setState(() => _locked = true);
  }

  /// Reads the `soty://invite?claim=...` route (and `soty://host` relay-host
  /// links) the engine delivered and queues the result for the UI.
  Future<void> _checkDeepLink() async {
    final route = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    await _handleRoute(route);
  }

  /// Accepts a `soty://` deep-link route, whether the platform launched the
  /// app with it or the user tapped one inside a message body. While the app
  /// lock is up the route is held and replayed after the unlock, so a link can
  /// never add a relay host or open a chat behind the lock.
  Future<void> _handleRoute(String route) => _deepLinks.submit(route);

  /// Applies an accepted route. Routes that are not one of our links are
  /// ignored.
  Future<void> _applyRoute(String route) async {
    final messenger = _messenger;
    if (messenger == null) return;
    debugPrint('Soty deep link route: $route');

    final HostEndpoint? hostEndpoint;
    try {
      hostEndpoint = HostLink.fromRoute(route);
    } on FormatException {
      _showInviteError('Invalid relay host link');
      return;
    }
    if (hostEndpoint != null) {
      // A relay link is an external intent: any page or app can launch it.
      // Require a pinned identity and explicit user consent before a hostile
      // link can add and dial an endpoint.
      if (hostEndpoint.edPubKey == null) {
        _showInviteError('Relay link must include a pinned key');
        return;
      }
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add relay host?'),
          content: Text(
            '${hostEndpoint!.addr}\n\n'
            'Identity: ${hostEndpoint.edPubKey}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      if (approved != true) return;
      final host = _findHostTransport(messenger);
      if (host == null) return;
      final added = await host.addHost(hostEndpoint);
      if (mounted) {
        _showInviteError(
          added ? 'Relay host added' : 'Relay host list is full',
        );
      }
      return;
    }

    final String? raw;
    try {
      raw = InviteLink.claimFromRoute(route);
    } on FormatException {
      _showInviteError('Invalid invite link');
      return;
    }
    if (raw == null) return;
    final IdentityClaim claim;
    try {
      claim = IdentityClaim.decode(raw);
    } on FormatException {
      _showInviteError('Invalid invite link');
      return;
    }
    final status = await claim.check();
    if (!mounted) return;
    if (status != ClaimStatus.valid) {
      _showInviteError('Insecure or expired invite');
      return;
    }
    setState(() => _pendingInvite = claim);
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_flushPendingInvite());
      });
    }
  }

  HostTransport? _findHostTransport(MessengerController messenger) {
    for (final transport in messenger.transports) {
      if (transport is HostTransport) return transport;
    }
    return null;
  }

  /// Hands the queued invite to the chat list once it is mounted; re-queues
  /// while the app lock is still covering the screen.
  Future<void> _flushPendingInvite() async {
    final claim = _pendingInvite;
    final chatsState = _chatsTabKey.currentState;
    if (claim == null || chatsState == null || !mounted) return;
    setState(() => _pendingInvite = null);
    // A link can be tapped inside a chat, so the invite must not open a second
    // copy of a chat on top of the one already on screen: return to the root
    // first and open the target conversation from the chat list.
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    await chatsState.openInvite(claim);
  }

  void _showInviteError(String message) {
    if (!mounted) return;
    final text = SotyL10n.forLocale(_prefs.locale, message);
    _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(text)));
  }

  List<String> _advertiseAddrs() {
    final fromDefine = _advertiseAddrDefine.isEmpty
        ? const <String>[]
        : <String>[_advertiseAddrDefine];
    return mergeAdvertisedAddrs(_lanAddrs.current, fromDefine);
  }

  static String _shortenKey(String key) => key.length <= 16
      ? key
      : '${key.substring(0, 8)}…${key.substring(key.length - 6)}';

  static HostEndpoint? get _bootstrapHost {
    final raw = _bootstrapHostDefine.isEmpty
        ? _defaultRelayHost
        : _bootstrapHostDefine;
    try {
      final fromLink = HostLink.fromRoute(raw);
      if (fromLink != null) return fromLink;
      return HostEndpoint.fromJson({'addr': raw, 'edPubKey': ''});
    } on FormatException {
      return null;
    }
  }

  Future<void> _bootstrap() async {
    try {
      final dir = await _dataDir();
      final db = await AppDatabase.open(dir.path);
      final identity = IdentityController(IdentityDao(db));
      try {
        await identity.load();
      } on IdentityUnavailableException catch (error) {
        // A restore without the Keystore key: the history is unreadable and
        // nothing in the app can repair it. Offer restore-or-start-over.
        debugPrint('Soty identity unavailable: $error');
        await db.close();
        if (!mounted) return;
        setState(() => _identityUnavailable = true);
        return;
      }
      if (identity.keyPair == null) {
        if (!mounted) return;
        setState(() {
          _db = db;
          _identity = identity;
          _needsOnboarding = true;
        });
        return;
      }
      await _startMessaging(db, identity);
    } catch (e, stack) {
      debugPrint('Soty bootstrap failed: $e\n$stack');
      if (mounted) {
        setState(() => _bootstrapError = e);
      }
    }
  }

  void _retryBootstrap() {
    setState(() => _identityUnavailable = false);
    unawaited(_bootstrap());
  }

  /// Erases the unreadable identity together with the local database and
  /// media, then bootstraps into onboarding, where a Soty backup file can be
  /// restored.
  Future<void> _startOver() async {
    final db = _db;
    _db = null;
    await db?.close();
    final dir = await _dataDir();
    await eraseLocalIdentityData(
      support: dir,
      secure: PlatformSecureIdentityStore(),
    );
    if (!mounted) return;
    setState(() {
      _identityUnavailable = false;
      _needsOnboarding = false;
    });
    await _bootstrap();
  }

  /// Rebuilds every controller around the identity a restore just wrote.
  ///
  /// A restore replaces the seeds, so the running controller still holds the
  /// old key pair and transports authenticated with it. Stopping them and
  /// re-running the bootstrap is the only way to guarantee nothing keeps
  /// signing with the replaced identity.
  Future<void> _restartAfterRestore() async {
    _pruneTimer?.cancel();
    _pruneTimer = null;
    _lanRefreshTimer?.cancel();
    _lanRefreshTimer = null;
    _presenceTimer?.cancel();
    _presenceTimer = null;
    final messenger = _messenger;
    _messenger = null;
    if (messenger != null) {
      await messenger.dispose();
      await messenger.processor.dispose();
    }
    for (final transport in _transports) {
      await transport.stop();
    }
    _transports.clear();
    _hostTransport = null;
    _p2pTransport = null;
    _meshTransport = null;
    _update?.dispose();
    _update = null;
    _settingsDao = null;
    _appLock = null;
    _locked = false;
    final db = _db;
    _db = null;
    _keyPair = null;
    _identity = null;
    await db?.close();
    if (!mounted) return;
    setState(() {
      _needsOnboarding = false;
      _bootstrapError = null;
      _identityUnavailable = false;
    });
    await _bootstrap();
  }

  Future<void> _finishOnboarding() async {
    final db = _db;
    final identity = _identity;
    if (db == null || identity == null) return;
    if (!mounted) return;
    setState(() => _needsOnboarding = false);
    await _startMessaging(db, identity);
  }

  Future<void> _startMessaging(
    AppDatabase db,
    IdentityController identity,
  ) async {
    try {
      final keyPair = identity.keyPair!;

      final messageDao = MessageDao(db);
      final peerDao = PeerDao(db);
      final prunedRootsDao = PrunedRootsDao(db);
      final settingsDao = SettingsDao(db);
      final conversationDao = ConversationDao(db);
      final mediaDao = MediaDao(db);
      _settingsDao = settingsDao;
      _prefs.attach(settingsDao);
      await _prefs.load();

      final maxActiveRaw = await settingsDao.get('soty.maxActivePeers');
      final maxActivePeers =
          int.tryParse(maxActiveRaw ?? '')?.clamp(1, maxActivePeersCeiling) ??
          maxActivePeersDefault;

      final processor = EnvelopeProcessor(identity: keyPair, dao: messageDao);

      final edPub = await keyPair.ed25519PublicKeyHex;
      final xPub = await keyPair.x25519PublicKeyHex;
      final displayName = identity.displayName;

      final mesh = MeshTransport(isKnownPeer: (id) => peerDao.hasPubKey(id));
      // Expose for UI to read mesh status (node counts, permissions).
      _meshTransport = mesh;
      final myClaim = await IdentityClaim.forIdentity(
        identity: keyPair,
        displayName: displayName,
      );
      final p2p = P2PTransport(
        ed25519SeedHex: await keyPair.ed25519SeedHex,
        myClaim: myClaim,
        selfAddrs: _advertiseAddrs,
        maxActivePeers: maxActivePeers,
      );
      final host = HostTransport(
        settings: settingsDao,
        lastTimestamp: () => messageDao.latestInboundTimestamp(xPub, edPub),
        peerIdProvider: () => p2p.localPeerId ?? '',
        advertiseAddrs: _advertiseAddrs,
        peerImport: p2p,
        peerCount: () => p2p.knownPeers.length,
        bootstrapHost: _bootstrapHost,
        retiredHosts: _retiredRelayHosts,
      );
      _hostTransport = host;

      processor.registerTransport(mesh);
      processor.registerTransport(p2p);
      processor.registerTransport(host);
      _transports.add(mesh);
      _transports.add(p2p);
      _transports.add(host);

      // Transports are best-effort: unsupported platforms stay offline.
      try {
        await mesh.start(
          myEdPubKey: edPub,
          myXPubKey: xPub,
          displayName: displayName,
        );
      } catch (e, stack) {
        debugPrint('mesh transport unavailable: $e\n$stack');
      }
      try {
        await p2p.start(
          myEdPubKey: edPub,
          myXPubKey: xPub,
          displayName: displayName,
        );
        debugPrint('Soty p2p ready: peerId ${p2p.localPeerId}');
      } catch (e, stack) {
        debugPrint('p2p transport unavailable: $e\n$stack');
      }
      await _lanAddrs.refresh();
      try {
        await host.start(
          myEdPubKey: edPub,
          myXPubKey: xPub,
          displayName: displayName,
        );
      } catch (e, stack) {
        debugPrint('host transport unavailable: $e\n$stack');
      }
      _startLanRefresh();

      final messenger = MessengerController(
        processor: processor,
        dao: messageDao,
        peerDao: peerDao,
        conversationDao: conversationDao,
        prunedRootsDao: prunedRootsDao,
        mediaDao: mediaDao,
        identity: keyPair,
        transports: _transports,
        storeOutgoing: () => _prefs.storeOutgoing,
        readReceipts: () => _prefs.readReceipts,
      );
      await messenger.init();
      messenger.startListening();
      // Peers are imported during init; probing before that sees an empty book
      // and would leave a freshly launched peer "last seen" for two minutes.
      _startPresenceRefresh(p2p);

      _registerDevExtensions(messenger);

      _startNotifications(messenger, processor);

      if (_prefs.background) {
        try {
          await BackgroundService().start();
        } catch (e, stack) {
          debugPrint('background service unavailable: $e\n$stack');
        }
      }

      _startPruning(messenger);

      final appLock = AppLockController(
        settingsDao,
        biometric: LocalBiometricAuth(),
      );
      await appLock.load();

      final update = !kSelfUpdate
          ? null
          : UpdateController(
              client: UpdateClient(
                currentVersion: kSotyVersion,
                releaseUrl: _updateUrlDefine.isEmpty
                    ? null
                    : Uri.tryParse(_updateUrlDefine),
              ),
              settings: settingsDao,
            );
      if (update != null) {
        await update.load();
        unawaited(update.checkIfDue());
      }

      if (!mounted) return;
      setState(() {
        _db = db;
        _keyPair = keyPair;
        _identity = identity;
        _messenger = messenger;
        _appLock = appLock;
        _settingsDao = settingsDao;
        _p2pTransport = p2p;
        _update = update;
        _locked = appLock.isEnabled;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (appLock.recoveredFromCorruptVerifier) {
          _messengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text(
                SotyL10n.forLocale(_prefs.locale, appLockResetNotice),
              ),
            ),
          );
        }
        unawaited(_checkDeepLink());
      });
    } catch (e, stack) {
      debugPrint('Soty bootstrap failed: $e\n$stack');
      if (mounted) {
        setState(() => _bootstrapError = e);
      }
    }
  }

  void _registerDevExtensions(MessengerController messenger) {
    if (!kDebugMode) return;
    bindOptional(
      InternetAddress.loopbackIPv4,
      4701,
      onWarning: (error) =>
          debugPrint('dev extensions unavailable on port 4701: $error'),
    ).then((s) {
      if (s == null) return;
      s.listen(
        (request) async {
          try {
            final body = await utf8.decoder.bind(request).join();
            final data = jsonDecode(body) as Map<String, dynamic>;
            if (data['action'] == 'backupExport') {
              // Debug-only helper for the two-device backup e2e: builds the
              // real document from the live identity and contact book.
              final password = data['password'];
              final db = _db;
              if (password is! String || db == null) {
                request.response.statusCode = HttpStatus.badRequest;
                request.response.write('bad request');
              } else {
                try {
                  final service = BackupService(
                    identityDao: IdentityDao(db),
                    peerDao: messenger.peerDao,
                  );
                  final raw = await service.exportBackup(password: password);
                  request.response.write(jsonEncode({'backup': raw}));
                } catch (e) {
                  request.response.statusCode = HttpStatus.badRequest;
                  request.response.write('export failed: $e');
                }
              }
              await request.response.close();
              return;
            }
            if (data['action'] == 'locale') {
              // Debug-only helper for the locale e2e: switches the whole app
              // to a shipped locale so the rendered labels can be inspected.
              final code = data['code'];
              if (code is! String || !SotyL10n.isSupported(Locale(code))) {
                request.response.statusCode = HttpStatus.badRequest;
                request.response.write('bad locale');
              } else {
                await _prefs.setLocale(Locale(code));
                request.response.write(
                  jsonEncode({'ok': true, 'locale': code}),
                );
              }
              await request.response.close();
              return;
            }
            if (data['action'] == 'backupExportStream') {
              final password = data['password'];
              final db = _db;
              if (password is! String || db == null) {
                request.response.statusCode = HttpStatus.badRequest;
                request.response.write('bad request');
              } else {
                try {
                  final dir = await Directory.systemTemp.createTemp(
                    'soty-e2e-backup',
                  );
                  final path = '${dir.path}/backup.soty';
                  final service = BackupService(
                    identityDao: IdentityDao(db),
                    peerDao: messenger.peerDao,
                  );
                  await service.exportBackupToFile(
                    path: path,
                    password: password,
                  );
                  request.response.write(
                    jsonEncode({
                      'path': path,
                      'size': await File(path).length(),
                    }),
                  );
                } catch (e) {
                  request.response.statusCode = HttpStatus.badRequest;
                  request.response.write('export failed: $e');
                }
              }
              await request.response.close();
              return;
            }
            if (data['action'] == 'backupImportStream') {
              final path = data['path'];
              final password = data['password'];
              final db = _db;
              if (path is! String ||
                  password is! String ||
                  db == null) {
                request.response.statusCode = HttpStatus.badRequest;
                request.response.write('bad request');
              } else {
                try {
                  final service = BackupService(
                    identityDao: IdentityDao(db),
                    peerDao: messenger.peerDao,
                  );
                  await service.restoreBackupFromFile(
                    path: path,
                    password: password,
                    replaceExisting: true,
                  );
                  request.response.write(jsonEncode({'ok': true}));
                } on BackupAuthFailure {
                  request.response.statusCode = HttpStatus.badRequest;
                  request.response.write('bad password');
                } on FormatException catch (e) {
                  request.response.statusCode = HttpStatus.badRequest;
                  request.response.write('bad backup: ${e.message}');
                }
              }
              await request.response.close();
              return;
            }
            if (data['action'] == 'backupImport') {
              final password = data['password'];
              final backup = data['backup'];
              final db = _db;
              if (password is! String || backup is! String || db == null) {
                request.response.statusCode = HttpStatus.badRequest;
                request.response.write('bad request');
              } else {
                try {
                  final service = BackupService(
                    identityDao: IdentityDao(db),
                    peerDao: messenger.peerDao,
                  );
                  final payload = await service.readBackup(
                    raw: backup,
                    password: password,
                  );
                  await service.restore(payload, replaceExisting: true);
                  request.response.write(jsonEncode({'ok': true}));
                } on BackupAuthFailure {
                  request.response.statusCode = HttpStatus.badRequest;
                  request.response.write('bad password');
                } on FormatException catch (e) {
                  request.response.statusCode = HttpStatus.badRequest;
                  request.response.write('bad backup: ${e.message}');
                }
              }
              await request.response.close();
              return;
            }
            if (data['action'] == 'identity') {
              // Debug builds only. The seeds live in the Android Keystore
              // (T-72), so the offline e2e tools cannot read them from a
              // pulled database; loopback on the emulator is the equivalent.
              final identity = _identity;
              final kp = identity?.keyPair;
              if (kp == null) {
                request.response.statusCode = HttpStatus.badRequest;
                request.response.write('no identity');
              } else {
                request.response.write(
                  jsonEncode({
                    'displayName': identity!.displayName,
                    'edSeedHex': await kp.ed25519SeedHex,
                    'xSeedHex': await kp.x25519SeedHex,
                  }),
                );
              }
              await request.response.close();
              return;
            }
            if (data['action'] == 'fileGen') {
              // Debug-only helper for the streaming e2e: writes a pattern file
              // into the app cache and sends it by path, without base64.
              final to = data['to'];
              final kindRaw = data['kind'];
              final mime = data['mime'];
              final size = data['size'];
              final kind = MediaKind.values
                  .where((candidate) => candidate.name == kindRaw)
                  .firstOrNull;
              if (to is! String ||
                  !isHexOfLength(to, 32) ||
                  kind == null ||
                  mime is! String ||
                  size is! int ||
                  size <= 0 ||
                  size > maxTransferBytes) {
                request.response.statusCode = HttpStatus.badRequest;
                request.response.write('bad request');
                await request.response.close();
                return;
              }
              try {
                final dir = await getTemporaryDirectory();
                final file = File(
                  '${dir.path}/soty-e2e-'
                  '${DateTime.now().millisecondsSinceEpoch}.bin',
                );
                final sink = file.openWrite();
                const chunk = 64 * 1024;
                var left = size;
                var seed = 0;
                while (left > 0) {
                  final n = left < chunk ? left : chunk;
                  final block = Uint8List(n);
                  for (var i = 0; i < n; i++) {
                    block[i] = (seed + i) % 251;
                  }
                  sink.add(block);
                  seed += n;
                  left -= n;
                }
                await sink.close();
                await messenger.sendFileToConversation(
                  conversationId: to,
                  kind: kind,
                  mime: mime,
                  path: file.path,
                  durationMs: 0,
                );
                request.response.write(
                  jsonEncode({'ok': true, 'size': size, 'path': file.path}),
                );
              } catch (e) {
                request.response.statusCode = HttpStatus.badRequest;
                request.response.write('send failed: $e');
              }
              await request.response.close();
              return;
            }
            if (data['action'] == 'file') {
              // Debug-only helper for the media e2e: sends a chunked file
              // exactly like the composer does, without a gallery picker.
              final to = data['to'];
              final kindRaw = data['kind'];
              final mime = data['mime'];
              final raw = data['data'];
              final kind = MediaKind.values
                  .where((candidate) => candidate.name == kindRaw)
                  .firstOrNull;
              if (to is! String ||
                  !isHexOfLength(to, 32) ||
                  kind == null ||
                  mime is! String ||
                  raw is! String) {
                request.response.statusCode = HttpStatus.badRequest;
                request.response.write('bad request');
                await request.response.close();
                return;
              }
              final List<int> bytes;
              try {
                bytes = base64Decode(raw);
              } on FormatException {
                request.response.statusCode = HttpStatus.badRequest;
                request.response.write('bad base64');
                await request.response.close();
                return;
              }
              await messenger.sendFileToConversation(
                conversationId: to,
                kind: kind,
                mime: mime,
                bytes: Uint8List.fromList(bytes),
                durationMs: (data['durationMs'] as int?) ?? 0,
              );
              request.response.write('ok');
              await request.response.close();
              return;
            }
            if (data['action'] == 'import') {
              final pubKey = data['pubKey'];
              if (pubKey is! String || !isHexOfLength(pubKey, 32)) {
                request.response.statusCode = HttpStatus.badRequest;
              } else {
                final addrs =
                    (data['addrs'] as List?)?.cast<String>() ?? const [];
                final imported = await messenger.importPeer(
                  DtmPeer(
                    pubKey: pubKey,
                    edPubKey: data['edPubKey'] as String?,
                    displayName: data['displayName'] as String? ?? '',
                    peerId: data['peerId'] as String?,
                    addrs: addrs,
                    lastSeen: DateTime.now(),
                  ),
                );
                request.response.write(imported ? 'ok' : 'rejected');
              }
              await request.response.close();
              return;
            }
            final to = data['to'];
            final text = data['text'];
            if (to is! String || text is! String || !isHexOfLength(to, 32)) {
              request.response.statusCode = HttpStatus.badRequest;
              await request.response.close();
              return;
            }
            final rawQuote = data['quote'];
            QuoteRef? quote;
            if (rawQuote is Map<String, dynamic>) {
              final refId = rawQuote['refId'];
              final authorX = rawQuote['authorX'];
              final preview = rawQuote['preview'];
              if (refId is! String ||
                  authorX is! String ||
                  preview is! String ||
                  !isHexOfLength(refId, 32) ||
                  !isHexOfLength(authorX, 32)) {
                request.response.statusCode = HttpStatus.badRequest;
                await request.response.close();
                return;
              }
              quote = QuoteRef(
                refId: refId,
                authorX: authorX,
                preview: preview,
              );
            }
            await messenger.sendText(
              recipientPubKey: to,
              plaintext: text,
              quote: quote,
            );
            request.response.write('ok');
          } catch (e) {
            request.response.statusCode = HttpStatus.internalServerError;
            request.response.write('$e');
          }
          await request.response.close();
        },
        onError: (Object error) =>
            debugPrint('dev extensions request failed: $error'),
      );
    });
  }

  /// Wires inbound messages to device notifications. Best-effort: platforms
  /// without a notifier fall back to silent.
  void _startNotifications(
    MessengerController messenger,
    EnvelopeProcessor processor,
  ) {
    final service = LocalNotificationService();
    _notificationService = service;
    unawaited(
      service
          .initialize(actionLabel: SotyL10n.forLocale(_prefs.locale, 'Open'))
          .onError((Object error, StackTrace stack) {
            debugPrint('notifications unavailable: $error\n$stack');
          }),
    );
    final chatNotifications = ChatNotifications(
      service: service,
      onDecrypted: () => processor.onDecrypted,
      resolvePeerPubKey: (ed) => messenger.peerByEdPubKey(ed)?.pubKey ?? ed,
      resolveTitle: (ed) {
        final peer = messenger.peerByEdPubKey(ed);
        if (peer?.displayName.isNotEmpty == true) return peer!.displayName;
        return _shortenKey(ed);
      },
      resolveGroup: messenger.groupTarget,
      isConversationVisible: (peerPubKey) =>
          messenger.visibleConversationId == peerPubKey,
      encryptedBody: SotyL10n.forLocale(_prefs.locale, 'Encrypted message'),
      mediaBody: (kind) => SotyL10n.forLocale(
        _prefs.locale,
        kind == MediaKind.voice
            ? 'Voice message'
            : kind == MediaKind.video
                ? 'Video'
                : kind == MediaKind.file
                    ? 'File'
                    : 'Photo',
      ),
    );
    chatNotifications.start();
    service.onNotificationTap.listen(_openChatFromNotification);
    messenger.onConversationRead = (conversationId) =>
        unawaited(chatNotifications.cancel(conversationId));
    _chatNotifications = chatNotifications;
  }

  /// Opens (or queues behind the app lock) the chat for a tapped notification.
  void _openChatFromNotification(String peerPubKey) {
    final messenger = _messenger;
    if (!mounted || messenger == null) return;
    if (_locked) {
      _pendingChatPeer = peerPubKey;
      return;
    }
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          conversationId: peerPubKey,
          messenger: messenger,
          prefs: _prefs,
          onSotyLink: _handleRoute,
        ),
      ),
    );
  }

  void _flushPendingChatPeer() {
    final peer = _pendingChatPeer;
    if (peer == null || !mounted) return;
    _pendingChatPeer = null;
    _openChatFromNotification(peer);
  }

  void _startPruning(MessengerController controller) {
    Future<void> run() async {
      try {
        await controller.reapplyRetention(retentionDays: _prefs.retentionDays);
      } catch (e, stack) {
        debugPrint('Pruning failed: $e\n$stack');
      }
    }

    unawaited(run());
    _pruneTimer = Timer.periodic(
      const Duration(hours: 24),
      (_) => unawaited(run()),
    );
  }

  /// Re-enumerates the local LAN addresses and, when the set changed,
  /// announces the new list to every relay so its peer list is fresh.
  Future<void> _refreshLanAddrs() async {
    final host = _hostTransport;
    final before = _lanAddrs.current;
    await _lanAddrs.refresh();
    if (host == null || _sameAddrSet(before, _lanAddrs.current)) return;
    try {
      await host.reannounce();
    } catch (e, stack) {
      debugPrint('LAN reannounce failed: $e\n$stack');
    }
  }

  static bool _sameAddrSet(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final set = a.toSet();
    return b.every(set.contains);
  }

  /// Probes known peers on launch and every two minutes, so online state and
  /// `lastSeen` do not depend on both devices opening at the same moment.
  void _startPresenceRefresh(P2PTransport p2p) {
    _presenceTimer?.cancel();
    unawaited(
      Future<void>.delayed(
        const Duration(seconds: 3),
        p2p.refreshPresence,
      ),
    );
    _presenceTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => unawaited(p2p.refreshPresence()),
    );
  }

  void _startLanRefresh() {
    _lanRefreshTimer?.cancel();
    _lanRefreshTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_refreshLanAddrs()),
    );
  }

  Future<Directory> _dataDir() async {
    if (kIsWeb) {
      return Directory.systemTemp;
    }
    try {
      final support = await getApplicationSupportDirectory();
      return support;
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _prefs,
      builder: (context, _) {
        return MaterialApp(
          title: 'Soty',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          scaffoldMessengerKey: _messengerKey,
          locale: _prefs.locale,
          supportedLocales: supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: _prefs.theme.toThemeMode(),
          builder: (context, child) => SotyL10n(
            locale: _prefs.locale,
            child: child ?? const SizedBox.shrink(),
          ),
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    final prefs = _prefs;
    if (_identityUnavailable) {
      return IdentityRecoveryScreen(
        onRetry: _retryBootstrap,
        onStartOver: _startOver,
      );
    }
    if (_bootstrapError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              SotyL10n.forLocale(
                prefs.locale,
                'Failed to start Soty:\n{error}',
                {'error': '$_bootstrapError'},
              ),
            ),
          ),
        ),
      );
    }
    if (_needsOnboarding) {
      final identity = _identity;
      if (identity == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return OnboardingScreen(
        identity: identity,
        onContinue: () => unawaited(_finishOnboarding()),
      );
    }
    final messenger = _messenger;
    final keyPair = _keyPair;
    final identity = _identity;
    if (messenger == null || keyPair == null || identity == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final appLock = _appLock;
    if (_locked && appLock != null) {
      return LockScreen(
        appLock: appLock,
        onUnlocked: () {
          setState(() => _locked = false);
          _flushPendingChatPeer();
          unawaited(_deepLinks.release());
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_flushPendingInvite());
          });
        },
      );
    }
    return HomeScreen(
      messenger: messenger,
      prefs: _prefs,
      chatsTabKey: _chatsTabKey,
      update: _update,
      onSotyLink: _handleRoute,
      onIdentity: () {
        _navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => IdentityScreen(
              identity: identity,
              messenger: messenger,
              transports: _transports,
            ),
          ),
        );
      },
      onSettings: () {
        _navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => SettingsScreen(
              identity: identity,
              messenger: messenger,
              appLock: _appLock!,
              settingsDao: _settingsDao,
              update: _update,
              p2pTransport: _p2pTransport,
              meshTransport: _meshTransport,
              notifications: _notificationService,
              prefs: _prefs,
              onIdentityRestored: _restartAfterRestore,
            ),
          ),
        );
      },
    );
  }
}
