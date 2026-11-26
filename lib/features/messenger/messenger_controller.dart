import 'dart:async';
import 'dart:convert' show base64Decode, base64Encode, utf8;
import 'dart:io' show File;
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

import '../../core/crypto/envelope_crypto.dart';
import '../../core/crypto/identity_claim.dart';
import '../../core/crypto/keypair.dart';
import '../../core/media/chunked_transfer.dart';
import '../../core/notifications/chat_notifications.dart'
    show encryptedPlaceholder;
import '../../core/search/message_search.dart';
import '../../core/security_limits.dart'
    show
        maxActivePeersCeiling,
        maxDisplayNameLength,
        maxGroupMembers,
        maxGroupTitleLength,
        autoDownloadBytes,
        maxActiveTransfers,
        maxStagingBytes,
        maxUnsolicitedConversations,
        maxConcurrentServesPerPeer,
        maxMediaBlobBytes,
        maxMediaCacheBytes,
        maxPeerAddrs,
        maxPlaintextBytes,
        maxPlaintextCacheEntries,
        maxOutstandingChunkRequests,
        senderPushBytes,
        maxSearchIndexMessages,
        maxTransferBytes,
        transferChunkBytes,
        relayedCacheMaxBytes,
        relayedCacheWindowMs,
        pendingBannerGraceMs;
import '../../core/storage/conversation_dao.dart';
import '../../core/storage/media_dao.dart';
import '../../core/storage/message_dao.dart';
import '../../core/storage/peer_dao.dart';
import '../../core/storage/pruned_roots_dao.dart';
import '../../core/storage/settings_dao.dart';
import '../../core/storage/transfer_dao.dart';
import '../../core/sync/envelope_processor.dart';
import '../../core/transport/transport.dart';
import '../../core/util/lru_cache.dart';
import '../../models/conversation.dart';
import '../../models/envelope.dart';
import '../../models/group_payload.dart';
import '../../models/message_payload.dart';
import '../../models/message_status.dart';
import '../../models/peer.dart';

/// One message as the UI renders it.
/// One voice note or photo attached to a [UiMessage]. Carries the bytes
/// inline (they are already in memory from the envelope or the blob cache),
/// plus the content address so a re-render can find them in storage.
class MediaAttachment {
  final String blobId;
  final MediaKind kind;
  final String mime;
  final int byteCount;
  final int durationMs;
  final String dataBase64;

  /// Relative path of a chunked file on disk; empty for inline media.
  final String filePath;

  const MediaAttachment({
    required this.blobId,
    required this.kind,
    required this.mime,
    required this.byteCount,
    required this.durationMs,
    required this.dataBase64,
    this.filePath = '',
  });

  bool get hasFile => filePath.isNotEmpty;

  Duration get duration => Duration(milliseconds: durationMs);

  bool get isVoice => kind == MediaKind.voice;

  bool get isPhoto => kind == MediaKind.photo;
}

/// Progress of an inbound chunked file that has not been assembled yet.
class TransferInfo {
  final String transferId;
  final MediaKind kind;
  final String mime;
  final int byteCount;
  final int receivedBytes;
  final int durationMs;

  /// False until the user taps a large file; small files start automatically.
  final bool started;

  /// Whether the sender is reachable right now. When false and nothing has
  /// arrived yet, the bubble tells the user to wait instead of pretending the
  /// file is downloading.
  final bool senderOnline;

  /// Whether the file can come from any group member that already has it.
  final bool isGroup;

  const TransferInfo({
    required this.transferId,
    required this.kind,
    required this.mime,
    required this.byteCount,
    required this.receivedBytes,
    required this.durationMs,
    this.started = true,
    this.senderOnline = false,
    this.isGroup = false,
  });

  /// A large file waits for an explicit tap before any slice is requested.
  bool get canStart => !started;

  Duration get duration => Duration(milliseconds: durationMs);

  /// 0..1, for the progress bar.
  double get progress =>
      byteCount <= 0 ? 0 : (receivedBytes / byteCount).clamp(0.0, 1.0);
}

class UiMessage {
  final String id;
  final bool outgoing;
  final int timestamp;
  final String body;

  /// Delivery status of one of our own envelopes; `null` for inbound ones.
  /// A group fan-out bubble carries the lowest status across its copies.
  final MessageStatus? status;

  /// Fan-out correlation id of a group message (`''` for anything else).
  /// Copies that share it collapse into a single bubble.
  final String corrId;

  /// Reply target of this message (`null` when it is not a reply).
  final QuoteRef? quote;

  /// X25519 address of the message's author, as carried in its container
  /// (`''` for a plain-text fallback or a legacy group container).
  final String senderX;

  /// The voice note or photo this message carries, or `null` for text.
  final MediaAttachment? media;

  /// Inbound file still being assembled; `null` once [media] is ready or for
  /// an ordinary message.
  final TransferInfo? transfer;

  /// Roster change rendered as a system line: action (`a`, `r`, `p`, `d`),
  /// actor and target X25519 keys. All empty for an ordinary message.
  final String systemAction;
  final String systemActor;
  final String systemTarget;

  bool get isSystem => systemAction.isNotEmpty;

  const UiMessage({
    required this.id,
    required this.outgoing,
    required this.timestamp,
    required this.body,
    this.status,
    this.corrId = '',
    this.systemAction = '',
    this.systemActor = '',
    this.systemTarget = '',
    this.quote,
    this.senderX = '',
    this.media,
    this.transfer,
  });

  /// Whether the bubble would show anything at all: a media bubble or a
  /// transfer in progress has an empty [body] but is not empty.
  bool get isEmpty =>
      body.isEmpty && media == null && transfer == null && !isSystem;

  /// Merges another copy of the same group fan-out into this bubble: the
  /// lowest of the two statuses wins, so "delivered" is shown only once every
  /// member's device has acknowledged the copy.
  UiMessage mergedWith(UiMessage other) => UiMessage(
        id: id,
        outgoing: outgoing,
        timestamp: timestamp,
        body: body,
        status: _lowerStatus(status, other.status),
        corrId: corrId,
        quote: quote,
        senderX: senderX,
        media: media ?? other.media,
        transfer: transfer ?? other.transfer,
      );

  static MessageStatus? _lowerStatus(MessageStatus? a, MessageStatus? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.index <= b.index ? a : b;
  }
}

/// Coordinates the chat features against the processor, storage and transports.
class MessengerController {
  final EnvelopeProcessor processor;
  final MessageDao dao;
  final PrunedRootsDao prunedRootsDao;
  final PeerDao peerDao;
  final ConversationDao conversationDao;
  final MediaDao mediaDao;
  final TransferDao transferDao;
  final SettingsDao settingsDao;
  final DtmKeyPair identity;

  late final String myXPubKey;
  late final String myEdPubKey;

  final List<Transport> _transports;
  final Map<String, DtmPeer> _peers = {};

  /// Local block list, mirrored into [EnvelopeProcessor.blockFilter]: the
  /// X25519 keys drive the UI, the Ed25519 keys drive envelope filtering.
  final Set<String> _blockedKeys = <String>{};
  final Set<String> _blockedEdKeys = <String>{};
  final Map<String, ConversationView> _conversations = {};

  /// Our own outbound plaintext, kept in memory only (never transmitted).
  /// When the user enables the `storeOutgoing` setting it is also mirrored
  /// into the local database so it survives a restart; the wire schema
  /// itself deliberately stores ciphertext only.
  ///
  /// Bounded by [maxPlaintextCacheEntries]: the keys are message ids from a
  /// long-lived session, so an unbounded map would grow until restart.
  final LruCache<String, String> _sentPlaintext = LruCache(
    maxEntries: maxPlaintextCacheEntries,
  );

  /// Decrypted plaintexts of inbound messages (session cache), same ceiling.
  final LruCache<String, String> _decrypted = LruCache(
    maxEntries: maxPlaintextCacheEntries,
  );

  /// Local search index: decrypted message metadata, newest
  /// [maxSearchIndexMessages] only. Never written to disk; rebuilt when a
  /// message arrives, history is pruned or a chat is marked read.
  List<SearchEntry>? _searchIndex;
  bool _searchDirty = true;

  final _tick = StreamController<void>.broadcast();

  /// How long a slice request may stay unanswered before it is re-issued.
  static const Duration _chunkRequestTimeout = Duration(seconds: 15);

  /// Missing slices requested per transfer, keyed by index and issue time.
  final Map<String, Map<int, DateTime>> _outstandingChunkRequests = {};

  /// Transfers whose pump loop is running right now (re-entrancy guard).
  final Set<String> _pumpingTransfers = {};

  /// Slices being served per peer, so one requester cannot pin the uplink.
  final Map<String, int> _servingPeers = {};

  /// Background futures the controller owns (storage writes and conversation
  /// refreshes started from a stream event). Drained by [dispose].
  final Set<Future<void>> _pending = <Future<void>>{};
  final _subs = <StreamSubscription<dynamic>>[];

  /// Whether the device persists the plaintext of its own sent messages in
  /// the local database (the user's `soty.storeOutgoing` setting).
  final bool Function() storeOutgoing;

  /// Whether opening a chat emits a read receipt to the counterpart (the
  /// user's `soty.readReceipts` setting). Defaults to on when unwired.
  final bool Function()? _readReceipts;

  MessengerController({
    required this.processor,
    required this.dao,
    required this.prunedRootsDao,
    required this.peerDao,
    required this.conversationDao,
    required this.identity,
    required this.storeOutgoing,
    MediaDao? mediaDao,
    TransferDao? transferDao,
    SettingsDao? settingsDao,
    bool Function()? readReceipts,
    List<Transport>? transports,
  })  : mediaDao = mediaDao ?? MediaDao(dao.attachedDatabase),
        transferDao = transferDao ?? TransferDao(dao.attachedDatabase),
        settingsDao = settingsDao ?? SettingsDao(dao.attachedDatabase),
        _transports = transports ?? const [],
        _readReceipts = readReceipts;

  bool get _sendsReadReceipts => _readReceipts?.call() ?? true;

  /// Fires after any message-related state change, to refresh the UI.
  Stream<void> get onChange => _tick.stream;

  /// A transport or processor event that lands after [dispose] must not
  /// throw into its stream: the UI is gone, so there is nobody to notify.
  /// Runs [task] without blocking the caller but keeps it owned by the
  /// controller, so [dispose] can wait for it instead of racing a closed
  /// database.
  void _background(Future<void> Function() task) {
    final future = _guardedBackground(task);
    _pending.add(future);
    unawaited(future.whenComplete(() => _pending.remove(future)));
  }

  static Future<void> _guardedBackground(Future<void> Function() task) async {
    try {
      await task();
    } catch (e) {
      debugPrint('[messenger] background task failed: $e');
    }
  }

  void _notifyChange() {
    if (_tick.isClosed) return;
    _tick.add(null);
  }

  DateTime _lastTransferTick =
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  /// Transfer progress arrives once per 64 KiB slice. Rebuilding every
  /// conversation row and the open chat hundreds of times per file is what
  /// made the window feel frozen, so progress ticks are coalesced to 4/s.
  void _notifyTransferProgress() {
    final now = DateTime.now();
    if (now.difference(_lastTransferTick) <
        const Duration(milliseconds: 250)) {
      return;
    }
    _lastTransferTick = now;
    _notifyChange();
  }

  /// Called with the conversation id the moment it is marked read, so the
  /// notification layer can drop a banner the user has already opened.
  void Function(String conversationId)? onConversationRead;

  Future<void> init() async {
    myXPubKey = await processor.myXPubKey;
    myEdPubKey = await processor.myEdPubKey;
    for (final stored in await peerDao.all()) {
      _peers[stored.pubKey] = stored;
    }
    _blockedKeys
      ..clear()
      ..addAll(await peerDao.blockedPubKeys());
    _blockedEdKeys
      ..clear()
      ..addAll(await peerDao.blockedEdKeys());
    processor.blockFilter =
        (edPubKey) => _blockedEdKeys.contains(edPubKey.toLowerCase());
    for (final t in _transports) {
      if (t is PeerImportable) {
        for (final peer in _peers.values) {
          (t as PeerImportable).importPeer(peer);
        }
      }
    }
    await _refreshConversations(backfill: true);
    _background(retryPending);
    _background(_resumeDownloads);
  }

  void startListening() {
    for (final t in _transports) {
      _subs.add(
        t.peers.listen((incoming) {
          final prev = _peers[incoming.pubKey];
          final peer = _mergePeer(prev, incoming);
          final effective =
              (prev?.isContact ?? false) && !peer.isContact
                  ? peer.copyWith(isContact: true)
                  : peer;
          final binding =
              peer.edPubKey != null && peer.edPubKey!.isNotEmpty;
          final routing = peer.peerId != null &&
              (prev?.peerId != peer.peerId ||
                  !_sameAddrs(prev?.addrs ?? const [], peer.addrs));
          _peers[peer.pubKey] = effective;
          _trackBlockedBinding(effective);
          if (binding || routing) {
            _background(() => _persistLearnedPeer(effective));
          }
          if (peer.edPubKey != null &&
              peer.edPubKey!.isNotEmpty &&
              prev?.edPubKey != peer.edPubKey) {
            _background(() => _refreshConversations(backfill: true));
          }
          if (effective.online && !(prev?.online ?? false)) {
            _background(retryPending);
            _background(_resumeDownloads);
          }
          _notifyChange();
        }),
      );
    }
    _subs.add(
      processor.onEnvelopeStored.listen((envelope) {
        // A message addressed to us materializes the chat on the Chats tab.
        // Relay copies (recipient != me) never create a conversation.
        if (envelope.recipientPubKey == myXPubKey) {
          // Tracked, so dispose() drains the inbound bookkeeping before the
          // database closes (and a test teardown cannot race the write).
          _background(() => _noteInbound(envelope));
        }
        _searchDirty = true;
        _notifyChange();
      }),
    );
    _subs.add(
      processor.onReceipt.listen(
        (message) => unawaited(_applyReceipt(message)),
      ),
    );
    _subs.add(processor.onDecrypted.listen((_) => _notifyChange()));
    _subs.add(processor.onStatusChanged.listen((_) => _notifyChange()));
  }

  /// Upserts a peer whose Ed25519/X25519 binding or routing the transport
  /// just learned (identify exchange / address update). Bounded: the peer
  /// book never outgrows [maxActivePeersCeiling], so a hostile identity
  /// flood cannot grow storage without bound.
  Future<void> _persistLearnedPeer(DtmPeer peer) async {
    await peerDao.upsert(peer);
    _trackBlockedBinding(peer);
    await peerDao.pruneTo(maxActivePeersCeiling);
  }

  /// Keeps the Ed25519 block list current when a blocked contact's binding is
  /// learned after the block: without this, their envelopes would pass the
  /// filter until the next restart.
  void _trackBlockedBinding(DtmPeer peer) {
    final ed = peer.edPubKey;
    if (_blockedKeys.contains(peer.pubKey) && ed != null && ed.isNotEmpty) {
      _blockedEdKeys.add(ed.toLowerCase());
    }
  }

  static bool _sameAddrs(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    return a.toSet().containsAll(b);
  }

  /// A transport may report a partial peer: a host presence feed carries the
  /// online flag and nothing else. Fields the incoming record did not learn
  /// are kept from what we already know, so a presence update can never wipe
  /// a name, an Ed25519 binding or the addresses we need to reach the peer.
  static DtmPeer _mergePeer(DtmPeer? prev, DtmPeer incoming) {
    if (prev == null) return incoming;
    return incoming.copyWith(
      edPubKey: incoming.edPubKey ?? prev.edPubKey,
      displayName: incoming.displayName.isEmpty
          ? prev.displayName
          : incoming.displayName,
      peerId: incoming.peerId ?? prev.peerId,
      addrs: incoming.addrs.isEmpty ? prev.addrs : incoming.addrs,
      isContact: prev.isContact || incoming.isContact,
      verifiedEdPubKey: prev.verifiedEdPubKey,
      verifiedAt: prev.verifiedAt,
    );
  }

  /// Applies the retention policy right now: the user's [retentionDays] for
  /// this device's own conversations (0 = keep forever) and the fixed
  /// hard policy for relayed envelopes. Safe to call whenever the setting or
  /// the database changes.
  Future<void> reapplyRetention({required int retentionDays}) async {
    await dao.pruneByPolicy(
      ownAge: retentionDays == 0 ? null : Duration(days: retentionDays),
      relayedAge: const Duration(milliseconds: relayedCacheWindowMs),
      relayedMaxBytes: relayedCacheMaxBytes,
      myEdPubKey: myEdPubKey,
      myXPubKey: myXPubKey,
      deviceKey: identity,
    );
    _searchDirty = true;
    // Media blobs follow the same age policy, so a pruned envelope and its
    // cached bytes disappear together and the cache can never grow unbounded.
    if (retentionDays > 0) {
      final cutoff = DateTime.now()
          .toUtc()
          .subtract(Duration(days: retentionDays))
          .millisecondsSinceEpoch;
      await mediaDao.pruneBefore(cutoff);
      await transferDao.pruneBefore(cutoff);
    }
    // The cache is bounded whatever the age policy says: a long media history
    // must not grow the device without limit.
    await mediaDao.pruneToBytes(maxMediaCacheBytes);
  }

  /// Peer directory (imported / discovered peers, keyed by X25519 pub key).
  Map<String, DtmPeer> get peers => Map.unmodifiable(_peers);

  /// The transports the app runs on (mesh, p2p, and any relay hosts).
  List<Transport> get transports => List.unmodifiable(_transports);

  /// Contacts the user can write to: explicitly imported peers plus anyone a
  /// 1:1 conversation exists with. Directory peers learned from trackers stay
  /// out of this list (but remain dialable/attributable).
  List<DtmPeer> get contacts {
    final all =
        _peers.values.where((p) => p.isContact).toList(growable: false);
    all.sort((a, b) {
      final byName = a.displayName
          .toLowerCase()
          .compareTo(b.displayName.toLowerCase());
      if (byName != 0) return byName;
      return a.pubKey.compareTo(b.pubKey);
    });
    return all;
  }

  /// Registers a peer from a handshake (QR / paste / invite). Persists it to
  /// the peer book. Returns `false` when the pub key is not a valid 32-byte
  /// hex key (rejected, not imported).
  Future<bool> importPeer(DtmPeer peer) async {
    if (!isHexOfLength(peer.pubKey, 32) || peer.pubKey.isEmpty) {
      return false;
    }
    final prev = _peers[peer.pubKey];
    final cleaned = peer
        .copyWith(
          addrs: peer.addrs.take(maxPeerAddrs).toList(growable: false),
          isContact: true,
        )
        // A re-import must not look like a fresh peer: keeping the previous
        // verification is what turns a swapped binding into a visible warning.
        .copyWith(
          verifiedEdPubKey: prev?.verifiedEdPubKey,
          verifiedAt: prev?.verifiedAt,
        );
    _peers[cleaned.pubKey] = cleaned;
    await peerDao.upsert(cleaned);
    _trackBlockedBinding(cleaned);
    for (final t in _transports) {
      if (t is PeerImportable) {
        (t as PeerImportable).importPeer(cleaned);
      }
    }
    // A fresh Ed25519→X25519 binding can fold an Ed-keyed DM into the canonical
    // chat, which only the backfill knows how to do.
    if (cleaned.edPubKey != null && cleaned.edPubKey!.isNotEmpty) {
      await _refreshConversations(backfill: true);
    }
    _notifyChange();
    return true;
  }

  /// Renames a peer (and therefore the chat) and persists the change.
  /// No-op for unknown keys. Bounds the name at [maxDisplayNameLength].
  Future<void> renamePeer(String pubKey, String displayName) async {
    final peer = _peers[pubKey];
    if (peer == null) return;
    final clamped = displayName.length > maxDisplayNameLength
        ? displayName.substring(0, maxDisplayNameLength)
        : displayName;
    final renamed = peer.copyWith(displayName: clamped);
    _peers[pubKey] = renamed;
    await peerDao.upsert(renamed);
    for (final t in _transports) {
      if (t is PeerImportable) {
        (t as PeerImportable).importPeer(renamed);
      }
    }
    _notifyChange();
  }

  /// Records that the user compared safety numbers with [pubKey] and confirms
  /// its current Ed25519 binding. Returns `false` for an unknown peer, a peer
  /// without a binding, or a malformed key.
  Future<bool> markPeerVerified(String pubKey) async {
    if (!isHexOfLength(pubKey, 32)) return false;
    final peer = _peers[pubKey] ?? await peerDao.find(pubKey);
    final binding = peer?.edPubKey;
    if (peer == null || binding == null || !isHexOfLength(binding, 32)) {
      return false;
    }
    await peerDao.markVerified(pubKey, binding);
    final verifiedAt = DateTime.now().toUtc();
    _peers[pubKey] = peer.copyWith(
      verifiedEdPubKey: binding.toLowerCase(),
      verifiedAt: verifiedAt,
    );
    _notifyChange();
    return true;
  }

  /// Imports a peer from a signed invite ([IdentityClaim] JSON). Returns
  /// `false` when the claim does not verify (forged/tampered invite).
  Future<bool> importInvite(String inviteJson) async {    try {
      final claim = IdentityClaim.decode(inviteJson);
      if (await claim.check() != ClaimStatus.valid) return false;
      return await importPeer(
        DtmPeer(
          pubKey: claim.xPubKey,
          edPubKey: claim.edPubKey,
          displayName: claim.displayName,
          lastSeen: DateTime.now(),
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Conversations, keyed by the remote peer's X25519 address. Inbound
  /// messages signed by a known peer's Ed25519 key are folded into that
  /// peer's X25519 conversation.
  Future<List<String>> conversations() async {
    final raw = await dao.conversationKeys(
      myXPubKey: myXPubKey,
      myEdPubKey: myEdPubKey,
    );
    final canonical = <String>{};
    for (final key in raw) {
      if (_peers.containsKey(key)) {
        canonical.add(key);
        continue;
      }
      final mapped = peerByEdPubKey(key);
      canonical.add(mapped?.pubKey ?? key);
    }
    return canonical.toList()..sort();
  }

  /// Cached chat list, newest activity first. Kept in sync whenever the
  /// conversation tables or the processed messages change.
  List<ConversationView> get conversationList {
    final out = _conversations.values.toList(growable: false);
    out.sort((a, b) => b.lastTs.compareTo(a.lastTs));
    return out;
  }

  /// The conversation currently on screen, if any. The chat screen owns this
  /// while it is open: it is what makes a notification redundant and what
  /// marks the conversation read. Notifications and badges must ask this
  /// instead of guessing from whether the app is in the foreground — a chat
  /// open in the foreground deserves no notification, and a chat that is not
  /// open deserves one even while the user is looking at another screen.
  ///
  /// A backgrounded app has no conversation on screen: the chat widget is
  /// still mounted, so without [setForeground] its messages would keep being
  /// treated as read and would raise no banner.
  String? get visibleConversationId =>
      _foreground ? _visibleConversationId : null;

  String? _visibleConversationId;
  bool _foreground = true;

  /// Whether the app is on screen. Called by the app shell on every
  /// lifecycle change. Coming back re-reads a chat that is still open, so a
  /// banner raised while the app was away does not outlive the reading.
  Future<void> setForeground(bool value) async {
    if (_foreground == value) return;
    _foreground = value;
    _notifyChange();
    final visible = _visibleConversationId;
    if (value) {
      unawaited(retryPending());
      if (visible != null) {
        await markConversationRead(visible);
      }
    }
  }

  /// Total unread across every conversation except the one on screen, which
  /// is what the chat tab badge shows.
  int get unreadTotal {
    final visible = visibleConversationId;
    var total = 0;
    for (final conversation in _conversations.values) {
      if (conversation.id == visible) continue;
      total += conversation.unreadCount;
    }
    return total;
  }

  /// Called by the chat screen when it opens (and again whenever the user
  /// comes back to it): marks the conversation read, clears the badge, and
  /// tells each counterpart that their messages were read.
  Future<void> markConversationRead(String conversationId) async {
    _visibleConversationId = conversationId;
    onConversationRead?.call(conversationId);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final current = _conversations[conversationId];
    final since = await conversationDao.readAt(conversationId);
    if (current != null && current.unreadCount == 0 && since >= now) return;
    await conversationDao.markRead(conversationId, now);
    _searchDirty = true;
    final stored = _conversations[conversationId];
    if (stored != null && stored.unreadCount > 0) {
      _conversations[conversationId] = stored.copyWith(unreadCount: 0);
    }
    await _sendReadReceipts(conversationId, since: since, until: now);
    _notifyChange();
  }

  /// Tells every counterpart whose messages just became read. Inbound
  /// envelopes are grouped by sender so each peer gets one receipt with all
  /// their ids; unknown senders (no X address) are skipped, they could not be
  /// addressed.
  Future<void> _sendReadReceipts(
    String conversationId, {
    required int since,
    required int until,
  }) async {
    if (!_sendsReadReceipts) return;
    final conversation = _conversations[conversationId];
    if (conversation == null) return;
    final List<Envelope> envelopes;
    if (conversation.isGroup) {
      final memberEdKeys = <String>[
        for (final key in conversation.memberKeys)
          _peers[key]?.edPubKey ?? key,
      ];
      envelopes = await dao.messagesForGroup(
        myXPubKey: myXPubKey,
        myEdPubKey: myEdPubKey,
        memberXKeys: conversation.memberKeys,
        memberEdKeys: memberEdKeys,
      );
    } else {
      envelopes = await dao.messagesFor(
        conversationId,
        myXPubKey: myXPubKey,
        myEdPubKey: myEdPubKey,
        peerEdPubKey: _peers[conversationId]?.edPubKey,
      );
    }
    final byMember = <String, List<String>>{};
    for (final envelope in envelopes) {
      if (envelope.senderPubKey == myEdPubKey) continue;
      if (envelope.timestamp <= since || envelope.timestamp > until) continue;
      final senderX = peerByEdPubKey(envelope.senderPubKey)?.pubKey;
      if (senderX == null || senderX == myXPubKey) continue;
      (byMember[senderX] ??= []).add(envelope.id);
    }
    for (final entry in byMember.entries) {
      await _sendReceipt(
        recipientPubKey: entry.key,
        kind: ReceiptKind.read,
        ids: entry.value,
      );
    }
  }

  /// Called by the chat screen when it closes.
  void clearVisibleConversation(String conversationId) {
    if (_visibleConversationId != conversationId) return;
    _visibleConversationId = null;
  }

  /// What the chat screen header shows for [peerPubKey]: the user rename of
  /// this 1:1 chat when set, else the contact's name, else a short key.
  String chatTitle(String peerPubKey) {
    final conversation = _conversations[peerPubKey];
    if (conversation != null && conversation.title.isNotEmpty) {
      return conversation.title;
    }
    final peer = _peers[peerPubKey];
    if (peer != null && peer.displayName.isNotEmpty) {
      return peer.displayName;
    }
    return _shorten(peerPubKey);
  }

  /// The label a group bubble puts above a member's message: the contact's
  /// name, else a short key, so a reader can always tell who wrote. Our own
  /// keys resolve to an empty string — an outgoing bubble needs no name.
  String senderNameFor(String peerXKey) {
    if (peerXKey == myXPubKey) return '';
    final peer = _peers[peerXKey];
    if (peer != null && peer.displayName.isNotEmpty) {
      return peer.displayName;
    }
    return _shorten(peerXKey);
  }

  /// Renames a *chat* without touching the contact's display name. A group
  /// rename is broadcast to all members as a title meta so it propagates.
  Future<void> renameConversation(String conversationId, String title) async {
    if (isGroup(conversationId) && !await isGroupAdmin(conversationId)) {
      return;
    }
    await conversationDao.rename(conversationId, title);
    if (isGroup(conversationId)) {
      await sendGroupTitle(conversationId: conversationId, title: title);
    }
    await _refreshConversations();
    _notifyChange();
  }

  /// Whether [conversationId] is a group (vs a 1:1 chat keyed by the peer
  /// X25519 address).
  bool isGroup(String conversationId) =>
      _conversations[conversationId]?.isGroup ?? false;

  /// The group a container belongs to, as a notification needs it: the group's
  /// row id and its display title. `null` for anything this device does not
  /// know to be a group, so a stranger's container raises no banner.
  ({String id, String title})? groupTarget(String conversationId) {
    if (!isGroup(conversationId)) return null;
    return (id: conversationId, title: chatTitle(conversationId));
  }

  /// The cached view of one conversation, or `null` when unknown.
  ConversationView? conversationView(String conversationId) =>
      _conversations[conversationId];

  /// Unread inbound count for one chat, read from the database instead of the
  /// cached conversation list. A chat screen opening right after another change
  /// would otherwise see a stale zero and mistake a backlog for a read chat.
  Future<int> unreadCountFor(String conversationId) async {
    final counts = await conversationDao.unreadCounts(
      myXPubKey: myXPubKey,
      myEdPubKey: myEdPubKey,
    );
    return counts[conversationId] ?? 0;
  }

  /// Stores a chunked-file manifest. The manifest is authenticated by the
  /// envelope and attributed to the peer the transport bound to its Ed25519
  /// key, never to the self-asserted container field.
  Future<void> _acceptFileManifest(
    Envelope envelope,
    FileManifestPayload payload,
  ) async {
    final senderX = peerByEdPubKey(envelope.senderPubKey)?.pubKey;
    if (senderX == null) return;
    final isGroupTransfer = payload.conversationId.isNotEmpty;
    if (isGroupTransfer) {
      final conversation = _conversations[payload.conversationId];
      if (conversation == null ||
          !conversation.isGroup ||
          !conversation.memberKeys.contains(senderX)) {
        return;
      }
    }
    final manifest = payload.manifest;
    await transferDao.putManifest(
      StoredTransfer(
        transferId: manifest.transferId,
        blobId: manifest.blobId,
        kind: payload.kind,
        mime: manifest.mime,
        byteCount: manifest.byteCount,
        chunkSize: manifest.chunkSize,
        chunkCount: manifest.chunkCount,
        sha256: manifest.sha256,
        durationMs: manifest.durationMs,
        senderX: senderX,
        conversationId: payload.conversationId,
        started: manifest.byteCount <= autoDownloadBytes,
        timestamp: envelope.timestamp,
      ),
    );
    await _boundTransfers();
    if (isGroupTransfer) {
      await conversationDao.setLastTs(
        payload.conversationId,
        envelope.timestamp,
      );
      await _refreshConversations();
    } else {
      await _noteChat(senderX, envelope.timestamp);
    }
    await _sendReceipt(
      recipientPubKey: senderX,
      kind: ReceiptKind.delivered,
      ids: [envelope.id],
    );
    _notifyChange();
    if (manifest.byteCount <= autoDownloadBytes) {
      // The sender pushes small files, but BLE can drop a slice. After a short
      // grace, pull whatever is still missing instead of waiting forever.
      final id = manifest.transferId;
      _background(() async {
        await Future<void>.delayed(const Duration(seconds: 2));
        final current = await transferDao.get(id);
        if (current == null || !current.started) return;
        await _pumpDownload(id);
      });
    }
  }

  /// Validates and stores one slice. Duplicates are ignored, a slice that
  /// fails its digest or length is dropped, and the last slice triggers the
  /// assembly. The whole file is checked against the manifest before it can
  /// become a blob, so a hostile sender cannot inject altered bytes.
  Future<void> _acceptFileChunk(
    Envelope envelope,
    FileChunkPayload payload,
  ) async {
    final senderX = peerByEdPubKey(envelope.senderPubKey)?.pubKey;
    if (senderX == null) return;
    final transfer = await transferDao.get(payload.chunk.transferId);
    if (transfer == null) return;
    if (transfer.conversationId.isEmpty) {
      // A 1:1 file may only be completed by the peer that announced it.
      if (transfer.senderX != senderX) return;
    } else {
      // In a group any member that already assembled the file can serve the
      // remaining slices, not just the original sender.
      final conversation = _conversations[transfer.conversationId];
      if (conversation == null ||
          !conversation.isGroup ||
          !conversation.memberKeys.contains(senderX)) {
        await transferDao.remove(transfer.transferId);
        return;
      }
    }
    final index = payload.chunk.index;
    if (index < 0 || index >= transfer.chunkCount) return;
    final Uint8List bytes;
    try {
      bytes = base64Decode(payload.chunk.dataBase64);
    } on FormatException {
      return;
    }
    final start = index * transfer.chunkSize;
    final remaining = transfer.byteCount - start;
    final expected = remaining < transfer.chunkSize
        ? remaining
        : transfer.chunkSize;
    if (bytes.length != expected) return;
    final digest = await Sha256().hash(bytes);
    if (_hexOf(digest.bytes) != payload.chunk.sha256) return;
    final inserted = await transferDao.putPart(
      transferId: transfer.transferId,
      index: index,
      byteCount: bytes.length,
      bytes: bytes,
    );
    if (!inserted) return;
    final count = await transferDao.partCount(transfer.transferId);
    _outstandingChunkRequests[transfer.transferId]?.remove(index);
    if (count < transfer.chunkCount) {
      _notifyTransferProgress();
      if (transfer.started) {
        _background(() => _pumpDownload(transfer.transferId));
      }
      return;
    }
    final path = await transferDao.assemble(transfer);
    if (path == null) return;
    if (transfer.byteCount <= maxMediaBlobBytes) {
      // Inline-sized media renders as base64, exactly like a voice note or a
      // photo sent in one envelope; no reason to keep a file around.
      final source = await mediaDao.store.blobFile(transfer.blobId);
      final data = await source.readAsBytes();
      await mediaDao.put(
        blobId: transfer.blobId,
        kind: transfer.kind,
        mime: transfer.mime,
        byteCount: transfer.byteCount,
        durationMs: transfer.durationMs,
        dataBase64: base64Encode(data),
        timestamp: envelope.timestamp,
      );
      await mediaDao.store.deleteBlob(transfer.blobId);
    } else {
      await mediaDao.putFile(
        blobId: transfer.blobId,
        kind: transfer.kind,
        mime: transfer.mime,
        byteCount: transfer.byteCount,
        durationMs: transfer.durationMs,
        path: path,
        timestamp: envelope.timestamp,
      );
    }
    await transferDao.markCompleted(transfer.transferId);
    _outstandingChunkRequests.remove(transfer.transferId);
    _notifyChange();
  }

  /// Answers a slice request from the sender or any group member that holds
  /// the file. A completed blob is sliced by offset; an in-flight transfer is
  /// served from its validated parts. Nothing is ever pushed unasked, so a
  /// large file only moves when the recipient explicitly starts it.
  Future<void> _acceptFileRequest(
    Envelope envelope,
    FileRequestPayload payload,
  ) async {
    final requester = peerByEdPubKey(envelope.senderPubKey)?.pubKey;
    if (requester == null) return;
    // A request must name the transfer we actually announced. Without this,
    // any peer that knows a group blob id could ask with an empty
    // conversationId and bypass the membership check below.
    final transfer = await transferDao.get(payload.transferId);
    if (transfer == null || transfer.blobId != payload.blobId) return;
    if (transfer.conversationId != payload.conversationId) return;
    if (payload.conversationId.isNotEmpty) {
      final conversation = _conversations[payload.conversationId];
      if (conversation == null ||
          !conversation.isGroup ||
          !conversation.memberKeys.contains(requester)) {
        return;
      }
    } else if (transfer.senderX != myXPubKey &&
        transfer.senderX != requester) {
      // Direct transfers have no conversation id. Only the sender of the
      // file (us) or the peer that sent it to us may ask for slices.
      return;
    }
    final serving = _servingPeers[requester] ?? 0;
    if (serving >= maxConcurrentServesPerPeer) return;
    _servingPeers[requester] = serving + 1;
    try {
      Uint8List? slice;
      final stored = await mediaDao.get(payload.blobId);
      if (stored != null) {
        final start = payload.index * transferChunkBytes;
        if (stored.hasFile) {
          final read = await stored.store.readSlice(
            stored.blobId,
            start,
            transferChunkBytes,
          );
          if (read.isNotEmpty) slice = read;
        } else {
          final whole = await stored.readBytes();
          if (start < whole.length) {
            final end = min(start + transferChunkBytes, whole.length);
            slice = Uint8List.sublistView(whole, start, end);
          }
        }
      } else {
        slice = await transferDao.part(transfer.transferId, payload.index);
      }
      if (slice == null) return;
      final digest = await Sha256().hash(slice);
      final chunk = FileChunk(
        transferId: payload.transferId,
        index: payload.index,
        dataBase64: base64Encode(slice),
        sha256: _hexOf(digest.bytes),
      );
      final container = payload.conversationId.isEmpty
          ? MessagePayload.composeFileChunkDirect(
              senderX: myXPubKey,
              chunk: chunk,
            )
          : MessagePayload.composeFileChunkGroup(
              conversationId: payload.conversationId,
              senderX: myXPubKey,
              chunk: chunk,
            );
      await _sendChunkPayload(requester, container);
    } finally {
      final left = (_servingPeers[requester] ?? 1) - 1;
      if (left <= 0) {
        _servingPeers.remove(requester);
      } else {
        _servingPeers[requester] = left;
      }
    }
  }

  /// Starts an explicit download of a large file (the user tapped the bubble)
  /// and requests the missing slices from every holder that is online.
  Future<void> startTransferDownload(String transferId) async {
    final transfer = await transferDao.get(transferId);
    if (transfer == null) return;
    if (!transfer.started) await transferDao.setStarted(transferId);
    _notifyChange();
    _background(() => _pumpDownload(transferId));
  }

  /// Requests the missing slices, up to [maxOutstandingChunkRequests] at a
  /// time, round-robin across the sender and the other group members. A
  /// holder may be offline; the direct-only request stays queued and is
  /// retried when the peer comes online.
  Future<void> _pumpDownload(String transferId) async {
    if (_pumpingTransfers.contains(transferId)) return;
    _pumpingTransfers.add(transferId);
    try {
      final transfer = await transferDao.get(transferId);
      if (transfer == null || !transfer.started) return;
      final have = await transferDao.partIndexes(transferId);
      final missing = <int>[
        for (var i = 0; i < transfer.chunkCount; i++)
          if (!have.contains(i)) i,
      ];
      if (missing.isEmpty) return;
      final candidates = _downloadCandidates(transfer);
      if (candidates.isEmpty) return;
      final outstanding = _outstandingChunkRequests.putIfAbsent(
        transferId,
        () => <int, DateTime>{},
      );
      final now = DateTime.now();
      outstanding.removeWhere(
        (index, at) =>
            have.contains(index) || now.difference(at) > _chunkRequestTimeout,
      );
      var slot = outstanding.length;
      var cursor = outstanding.length;
      for (final index in missing) {
        if (slot >= maxOutstandingChunkRequests) break;
        if (outstanding.containsKey(index)) continue;
        final target = candidates[cursor % candidates.length];
        cursor++;
        outstanding[index] = now;
        slot++;
        unawaited(_requestSlice(target, transfer, index));
      }
    } finally {
      _pumpingTransfers.remove(transferId);
    }
  }

  Future<void> _requestSlice(
    String target,
    StoredTransfer transfer,
    int index,
  ) async {
    final container = transfer.conversationId.isEmpty
        ? MessagePayload.composeFileRequestDirect(
            senderX: myXPubKey,
            transferId: transfer.transferId,
            blobId: transfer.blobId,
            index: index,
          )
        : MessagePayload.composeFileRequestGroup(
            conversationId: transfer.conversationId,
            senderX: myXPubKey,
            transferId: transfer.transferId,
            blobId: transfer.blobId,
            index: index,
          );
    try {
      await _sendChunkPayload(target, container);
    } catch (_) {
      // The request stays outstanding and is retried after the timeout.
    }
  }

  /// Peers to ask for slices: the manifest sender first, then every other
  /// member of the group. Online peers are tried before offline ones.
  List<String> _downloadCandidates(StoredTransfer transfer) {
    final ordered = <String>[];
    void add(String key) {
      if (key.isEmpty || key == myXPubKey || ordered.contains(key)) return;
      ordered.add(key);
    }

    add(transfer.senderX);
    if (transfer.conversationId.isNotEmpty) {
      final conversation = _conversations[transfer.conversationId];
      if (conversation != null) {
        for (final member in conversation.memberKeys) {
          add(member);
        }
      }
    }
    final online = [
      for (final key in ordered)
        if (_peers[key]?.online ?? false) key,
    ];
    return [
      ...online,
      for (final key in ordered)
        if (!online.contains(key)) key,
    ];
  }

  Future<void> _resumeDownloads() async {
    for (final transfer in await transferDao.startedTransfers()) {
      // Push and pull are complementary: a lost slice is requested again even
      // for a file the sender was pushing automatically.
      _background(() => _pumpDownload(transfer.transferId));
    }
  }

  /// Concatenates the slices in index order and verifies the whole-file
  /// digest. A complete but inconsistent set is dropped rather than retried
  /// forever: the staging quota must not be pinned by a bad transfer.
  /// Keeps the staging area bounded by dropping the oldest incomplete
  /// transfers. A flood of manifests can therefore never grow storage without
  /// limit.
  Future<void>? _bounding;

  Future<void> _boundTransfers() async {
    while (_bounding != null) {
      await _bounding;
    }
    final future = _boundTransfersOnce();
    _bounding = future;
    try {
      await future;
    } finally {
      if (identical(_bounding, future)) _bounding = null;
    }
  }

  Future<void> _boundTransfersOnce() async {
    var count = await transferDao.count();
    var bytes = await transferDao.totalBytes();
    while (count > maxActiveTransfers || bytes > maxStagingBytes) {
      final oldest = await transferDao.oldest();
      if (oldest == null) return;
      await transferDao.remove(oldest.transferId);
      count = await transferDao.count();
      bytes = await transferDao.totalBytes();
    }
  }

  Future<void> _noteInbound(Envelope envelope) async {
    final plaintext = await _decrypt(envelope);
    final payload = MessagePayload.parse(plaintext);
    if (payload is ReceiptPayload || payload is DroppedPayload) return;
    if (payload is FileManifestPayload) {
      await _acceptFileManifest(envelope, payload);
      return;
    }
    if (payload is FileChunkPayload) {
      await _acceptFileChunk(envelope, payload);
      return;
    }
    if (payload is FileRequestPayload) {
      await _acceptFileRequest(envelope, payload);
      return;
    }
    if (payload is GroupMessagePayload) {
      await _noteGroup(envelope, payload);
      return;
    }
    final known = peerByEdPubKey(envelope.senderPubKey);
    final chatId = known?.pubKey ?? envelope.senderPubKey;
    if (known == null && !_conversations.containsKey(chatId)) {
      final unsolicited = _conversations.values
          .where((c) => !c.isGroup && !_peers.containsKey(c.id))
          .length;
      if (unsolicited >= maxUnsolicitedConversations) return;
    }
    // Never address a receipt to the self-asserted `senderX` of an unknown
    // peer: that would let anyone make this device emit envelopes to an
    // arbitrary third-party X key.
    final senderX = known?.pubKey;
    await _noteChat(chatId, envelope.timestamp);
    if (senderX != null) {
      await _sendReceipt(
        recipientPubKey: senderX,
        kind: ReceiptKind.delivered,
        ids: [envelope.id],
      );
    }
    await _readIfVisible(chatId);
  }

  /// A group container from a member joins/updates the conversation and is
  /// acknowledged. A title meta only renames. A container from a non-member
  /// (or a peer the device cannot map to an X address) is dropped, so a
  /// stranger can never inject into a group nor leak one into a 1:1 chat.
  Future<void> _noteGroup(
    Envelope envelope,
    GroupMessagePayload payload,
  ) async {
    final conversationId = payload.conversationId;
    final senderX = peerByEdPubKey(envelope.senderPubKey)?.pubKey;
    var conversation = _conversations[conversationId];
    if (conversation == null) {
      if (senderX == null) return;
      final roster = payload.kind == GroupContainerKind.roster
          ? payload.rosterKeys
          : [myXPubKey, senderX];
      if (payload.kind == GroupContainerKind.roster &&
          (payload.rosterAction != 'c' ||
              !roster.contains(senderX) ||
              !roster.contains(myXPubKey))) {
        return;
      }
      await conversationDao.createGroup(
        id: conversationId,
        memberKeys: roster,
        title: payload.kind == GroupContainerKind.title ? payload.value : '',
        ts: envelope.timestamp,
        adminKeys: payload.kind == GroupContainerKind.roster
            ? [senderX]
            : const [],
      );
      await _refreshConversations();
      conversation = _conversations[conversationId];
      if (conversation == null) return;
    }
    if (!conversation.isGroup) return;
    if (senderX == null || !conversation.memberKeys.contains(senderX)) {
      return;
    }
    if (payload.kind == GroupContainerKind.roster) {
      await _applyRosterEnvelope(
        envelope: envelope,
        payload: payload,
        conversationId: conversationId,
        senderX: senderX,
      );
      return;
    }
    await dao.markGroup(envelope.id, groupId: conversationId);
    if (payload.kind == GroupContainerKind.title) {
      if (!await conversationDao.isAdmin(conversationId, senderX)) {
        return;
      }
      if (payload.value.isNotEmpty) {
        await conversationDao.rename(conversationId, payload.value);
      }
    } else {
      await _sendReceipt(
        recipientPubKey: senderX,
        kind: ReceiptKind.delivered,
        ids: [envelope.id],
      );
    }
    if (envelope.timestamp > conversation.lastTs) {
      await conversationDao.setLastTs(conversationId, envelope.timestamp);
    }
    await _refreshConversations();
    await _readIfVisible(conversationId);
  }

  /// Applies an admin's full-roster sync. The sender must be a current admin;
  /// the new roster must keep at least one admin and stay within the ceiling
  /// (both enforced by the DAO). Malformed or hostile updates are dropped.
  Future<void> _applyRosterEnvelope({
    required Envelope envelope,
    required GroupMessagePayload payload,
    required String conversationId,
    required String senderX,
  }) async {
    if (!await conversationDao.isAdmin(conversationId, senderX)) return;
    try {
      await conversationDao.replaceMembers(
        conversationId,
        payload.rosterKeys,
      );
      switch (payload.rosterAction) {
        case 'p':
          await conversationDao.setRole(
            conversationId,
            payload.value,
            ConversationDao.adminRole,
          );
        case 'd':
          await conversationDao.setRole(
            conversationId,
            payload.value,
            ConversationDao.memberRole,
          );
        default:
          break;
      }
    } on ArgumentError {
      return;
    } on StateError {
      return;
    }
    if (payload.rosterAction == 'c') {
      // The creation sync only seeds the roster: keep it out of unread
      // badges and per-chat previews.
      await dao.markControl(envelope.id);
    } else {
      await dao.markGroup(envelope.id, groupId: conversationId);
    }
    if (envelope.timestamp >
        (_conversations[conversationId]?.lastTs ?? 0)) {
      await conversationDao.setLastTs(conversationId, envelope.timestamp);
    }
    await _refreshConversations();
    await _readIfVisible(conversationId);
  }

  /// Sends a delivery/read receipt for one or more of our inbound envelopes.
  Future<void> _sendReceipt({
    required String recipientPubKey,
    required ReceiptKind kind,
    required List<String> ids,
  }) async {
    if (ids.isEmpty || recipientPubKey == myXPubKey) return;
    // One receipt frame carries at most [maxReceiptIds] ids; a longer batch is
    // split instead of silently dropped, or the tail would never be acked.
    final frames = MessagePayload.composeReceipts(kind: kind, ids: ids);
    for (final frame in frames) {
      await _sendPayload(recipientPubKey, frame, control: true);
    }
  }

  /// Applies an inbound delivery/read receipt. A receipt is only honoured when
  /// its signer is the peer the referenced envelope was addressed to, so a
  /// relay that merely saw a ciphertext can never forge "delivered"/"read".
  Future<void> _applyReceipt(DecryptedMessage message) async {
    final payload = MessagePayload.parse(message.plaintext);
    if (payload is! ReceiptPayload) return;
    final senderX = peerByEdPubKey(message.senderPubKey)?.pubKey;
    if (senderX == null) return;
    final status = payload.kind == ReceiptKind.read
        ? MessageStatus.read
        : MessageStatus.delivered;
    var advanced = false;
    for (final id in payload.ids) {
      final envelope = await dao.envelopeById(id);
      if (envelope == null) continue;
      if (envelope.senderPubKey != myEdPubKey) continue;
      if (envelope.recipientPubKey != senderX) continue;
      await dao.setStatus(id, status);
      advanced = true;
    }
    if (advanced) _notifyChange();
  }

  /// Re-pushes every queued outgoing envelope whose status is still below
  /// `sent`, so a message composed while offline advances once a transport or
  /// a peer comes back. Bounded by [maxPendingOutbound].
  Future<void> retryPending() async {
    for (final id in await dao.pendingOutboundIds()) {
      final envelope = await dao.envelopeById(id);
      if (envelope != null) await processor.redispatch(envelope);
    }
  }

  /// A message landing in the conversation the user is looking at is read the
  /// moment it arrives, so the badge never counts what is already on screen.
  /// Backgrounded, nothing is on screen, so the message stays unread.
  Future<void> _readIfVisible(String conversationId) async {
    if (visibleConversationId != conversationId) return;
    await markConversationRead(conversationId);
  }

  Future<void> _noteChat(String peerPubKey, int ts) async {
    await conversationDao.ensureOneOnOne(peerPubKey, ts: ts);
    final current = _conversations[peerPubKey];
    if (current != null && ts > current.lastTs) {
      await conversationDao.setLastTs(peerPubKey, ts);
    }
    await _refreshConversations();
  }

  /// Rebuilds the conversation list.
  ///
  /// [backfill] runs the one-off 1:1 materialization (a full scan of the
  /// message table). It is needed on startup and when a new Ed25519→X25519
  /// binding is learned, not on every arriving message: doing it per envelope
  /// turned each delivery into an O(history) scan.
  Future<void> _refreshConversations({bool backfill = false}) async {
    if (backfill) {
      await conversationDao.backfillOneOnOne(
        myXPubKey: myXPubKey,
        myEdPubKey: myEdPubKey,
        learnedEdToX: {
          for (final p in _peers.values)
            if (p.edPubKey != null && p.edPubKey!.isNotEmpty)
              p.edPubKey!: p.pubKey,
        },
      );
    }
    final conversations = await conversationDao.all(
      myXPubKey: myXPubKey,
      myEdPubKey: myEdPubKey,
    );
    _conversations
      ..clear()
      ..addEntries([for (final c in conversations) MapEntry(c.id, c)]);
    for (final c in conversations) {
      if (c.isGroup) continue;
      final peer = _peers[c.id];
      if (peer != null && !peer.isContact) {
        final promoted = peer.copyWith(isContact: true);
        _peers[c.id] = promoted;
        await peerDao.upsert(promoted);
      }
    }
  }

  static String _shorten(String key) => key.length <= 16
      ? key
      : '${key.substring(0, 8)}…${key.substring(key.length - 6)}';

  /// Renders one conversation.
  ///
  /// [limit] caps a 1:1 chat to its newest envelopes so opening a long history
  /// does not decode and lay out the whole archive. Groups always load whole:
  /// a fan-out puts one copy per member in the pool, and collapsing those into
  /// one bubble needs every copy of a correlation id in the same pass.
  /// Searches decrypted message text. The index is built lazily from the local
  /// history and never persisted, so pruned rows disappear on the next build.
  Future<List<SearchEntry>> searchMessages(MessageSearch query) async {
    final index = await _ensureSearchIndex();
    return runSearch(index, query);
  }

  /// Forces the next query to rebuild the index (tests, bulk edits).
  void invalidateSearchIndex() {
    _searchDirty = true;
  }

  Future<List<SearchEntry>> _ensureSearchIndex() async {
    final cached = _searchIndex;
    if (cached != null && !_searchDirty) return cached;
    final built = await _buildSearchIndex();
    _searchIndex = built;
    _searchDirty = false;
    return built;
  }

  Future<List<SearchEntry>> _buildSearchIndex() async {
    final entries = <SearchEntry>[];
    var remaining = maxSearchIndexMessages;
    final conversations = await conversationDao.all(
      myXPubKey: myXPubKey,
      myEdPubKey: myEdPubKey,
    );
    for (final conversation in conversations) {
      if (remaining <= 0) break;
      final readAt = await conversationDao.readAt(conversation.id);
      final messages = await messagesFor(conversation.id, limit: remaining);
      for (final message in messages) {
        if (remaining <= 0) break;
        remaining--;
        final timestamp = message.timestamp;
        entries.add(
          SearchEntry(
            id: message.id,
            conversationId: conversation.id,
            conversationTitle: chatTitle(conversation.id),
            body: message.body,
            timestamp: timestamp,
            outgoing: message.outgoing,
            unread: !message.outgoing && timestamp > readAt,
            media: message.media?.kind,
          ),
        );
      }
    }
    return entries;
  }

  /// Counts how many times a conversation was re-read and re-decoded. A burst
  /// of incoming envelopes must collapse into one pass instead of one per
  /// envelope; `chat_incremental_burst` asserts on this counter.
  @visibleForTesting
  int messageRenderPasses = 0;

  Future<List<UiMessage>> messagesFor(
    String conversationId, {
    int? limit,
  }) async {
    final conversation = _conversations[conversationId];
    if (conversation != null && conversation.isGroup) {
      return _groupMessages(conversation, limit: limit);
    }
    return _dmMessages(conversationId, limit: limit);
  }

  Future<List<UiMessage>> _dmMessages(
    String peerPubKey, {
    int? limit,
  }) async {
    messageRenderPasses++;
    final envelopes = await dao.messagesFor(
      peerPubKey,
      myXPubKey: myXPubKey,
      myEdPubKey: myEdPubKey,
      peerEdPubKey: _peers[peerPubKey]?.edPubKey,
      limit: limit,
    );
    final statuses = await dao.statusesFor(_outgoingIds(envelopes));
    final out = <UiMessage>[];
    for (final envelope in envelopes) {
      final message = await _render(envelope, statuses[envelope.id]);
      if (message != null) out.add(message);
    }
    return out;
  }

  Future<List<UiMessage>> _groupMessages(
    ConversationView conversation, {
    int? limit,
  }) async {
    messageRenderPasses++;
    final memberEdKeys = <String>[
      for (final key in conversation.memberKeys)
        _peers[key]?.edPubKey ?? key,
    ];
    final envelopes = await dao.messagesForGroup(
      myXPubKey: myXPubKey,
      myEdPubKey: myEdPubKey,
      memberXKeys: conversation.memberKeys,
      memberEdKeys: memberEdKeys,
      limit: limit,
    );
    final statuses = await dao.statusesFor(_outgoingIds(envelopes));
    final out = <UiMessage>[];
    final byCorr = <String, int>{};
    for (final envelope in envelopes) {
      final message = await _renderGroupMessage(
        envelope,
        statuses[envelope.id],
      );
      if (message == null || message.isEmpty) continue;
      if (message.corrId.isEmpty) {
        out.add(message);
        continue;
      }
      final index = byCorr[message.corrId];
      if (index == null) {
        byCorr[message.corrId] = out.length;
        out.add(message);
      } else {
        out[index] = out[index].mergedWith(message);
      }
    }
    return out;
  }

  Iterable<String> _outgoingIds(List<Envelope> envelopes) => [
        for (final envelope in envelopes)
          if (envelope.senderPubKey == myEdPubKey) envelope.id,
      ];

  DtmPeer? peerByEdPubKey(String edPubKey) {
    for (final peer in _peers.values) {
      if (peer.edPubKey == edPubKey) return peer;
    }
    return null;
  }

  /// Whether the user blocked this X25519 contact.
  bool isPeerBlocked(String pubKey) => _blockedKeys.contains(pubKey);

  /// Blocks or unblocks a contact. The flag is local-only; once set, the
  /// processor drops that contact's envelopes before decryption.
  Future<void> setPeerBlocked(String pubKey, bool blocked) async {
    if (pubKey.length != 64) {
      throw const FormatException('peer key is not 32-byte hex');
    }
    await peerDao.setBlocked(pubKey, blocked);
    final ed = _peers[pubKey]?.edPubKey ??
        (await peerDao.find(pubKey))?.edPubKey;
    if (blocked) {
      _blockedKeys.add(pubKey);
      if (ed != null && ed.isNotEmpty) {
        _blockedEdKeys.add(ed.toLowerCase());
      }
    } else {
      _blockedKeys.remove(pubKey);
      if (ed != null) _blockedEdKeys.remove(ed.toLowerCase());
    }
    _notifyChange();
  }

  Future<UiMessage?> _render(
    Envelope envelope,
    MessageStatus? status,
  ) async {
    final outgoing = envelope.senderPubKey == myEdPubKey;
    final raw = outgoing
        ? (_sentPlaintext[envelope.id] ??
            (storeOutgoing() ? await dao.bodyFor(envelope.id) : null))
        : await _decrypt(envelope);
    if (raw == null) {
      return UiMessage(
        id: envelope.id,
        outgoing: outgoing,
        timestamp: envelope.timestamp,
        body: encryptedPlaceholder,
        status: outgoing ? status : null,
      );
    }
    final payload = MessagePayload.parse(raw);
    if (payload is FileManifestPayload) {
      return _renderFileManifest(envelope, payload, status, outgoing: outgoing);
    }
    if (payload is MediaPayload) {
      final media = await _attachMedia(payload);
      if (media == null) return null;
      return UiMessage(
        id: envelope.id,
        outgoing: outgoing,
        timestamp: envelope.timestamp,
        body: '',
        status: outgoing ? status : null,
        quote: payload.quote,
        senderX: outgoing
            ? myXPubKey
            : (peerByEdPubKey(envelope.senderPubKey)?.pubKey ?? ''),
        media: media,
      );
    }
    final body = switch (payload) {
      DirectPayload(:final text) => text,
      TextPayload(:final text) => text,
      _ => null,
    };
    if (body == null) return null;
    final direct = payload is DirectPayload ? payload : null;
    return UiMessage(
      id: envelope.id,
      outgoing: outgoing,
      timestamp: envelope.timestamp,
      body: body,
      status: outgoing ? status : null,
      quote: direct?.quote,
      senderX: outgoing
          ? myXPubKey
          : (peerByEdPubKey(envelope.senderPubKey)?.pubKey ?? ''),
    );
  }

  Future<String> _decrypt(Envelope envelope) async {
    final cached = _decrypted[envelope.id];
    if (cached != null) return cached;
    final plaintext = await decryptPayload(
      envelope: envelope,
      recipientX25519KeyPair: identity.xKeyPair,
      senderEd25519PubKeyHex: envelope.senderPubKey,
    );
    if (plaintext == null) return encryptedPlaceholder;
    _decrypted[envelope.id] = plaintext;
    return plaintext;
  }

  /// Resolves a group envelope's plaintext. Title metadata never becomes a
  /// bubble (it was already applied when the envelope arrived); anything a
  /// non-member or a foreign group slipped in renders as nothing.
  Future<UiMessage?> _renderGroupMessage(
    Envelope envelope,
    MessageStatus? status,
  ) async {
    final outgoing = envelope.senderPubKey == myEdPubKey;
    final raw = outgoing
        ? (_sentPlaintext[envelope.id] ??
            (storeOutgoing() ? await dao.bodyFor(envelope.id) : null))
        : await _decrypt(envelope);
    if (raw == null) return null;
    final payload = MessagePayload.parse(raw);
    if (payload is FileManifestPayload) {
      return _renderFileManifest(envelope, payload, status, outgoing: outgoing);
    }
    if (payload is MediaPayload) {
      final media = await _attachMedia(payload);
      if (media == null) return null;
      return UiMessage(
        id: envelope.id,
        outgoing: outgoing,
        timestamp: envelope.timestamp,
        body: '',
        corrId: payload.corrId,
        status: outgoing ? status : null,
        quote: payload.quote,
        senderX: outgoing
            ? myXPubKey
            : (peerByEdPubKey(envelope.senderPubKey)?.pubKey ?? ''),
        media: media,
      );
    }
    if (payload is! GroupMessagePayload) return null;
    if (payload.kind == GroupContainerKind.title) return null;
    if (payload.kind == GroupContainerKind.roster) {
      // The creation sync only seeds the roster; it is not a visible event.
      if (payload.rosterAction == 'c') return null;
      return UiMessage(
        id: envelope.id,
        outgoing: outgoing,
        timestamp: envelope.timestamp,
        body: '',
        systemAction: payload.rosterAction,
        systemActor: outgoing
            ? myXPubKey
            : (peerByEdPubKey(envelope.senderPubKey)?.pubKey ?? ''),
        systemTarget: payload.value,
      );
    }
    return UiMessage(
      id: envelope.id,
      outgoing: outgoing,
      timestamp: envelope.timestamp,
      body: payload.value,
      corrId: payload.corrId,
      status: outgoing ? status : null,
      quote: payload.quote,
      senderX: outgoing
          ? myXPubKey
          : (peerByEdPubKey(envelope.senderPubKey)?.pubKey ?? ''),
    );
  }

  /// Composes a 1:1 message and hands it to the transports. The plaintext
  /// carries this device's X25519 address ([MessagePayload.composeDirect]), so
  /// even a recipient with no peer-book binding can address a receipt back.
  Future<void> sendText({
    required String recipientPubKey,
    required String plaintext,
    QuoteRef? quote,
  }) async {
    final envelope = await _sendPayload(
      recipientPubKey,
      MessagePayload.composeDirect(
        senderX: myXPubKey,
        text: plaintext,
        quote: quote,
      ),
    );
    await _noteChat(recipientPubKey, envelope.timestamp);
    _notifyChange();
  }

  /// Low-level send: stores the envelope, remembers the plaintext for the
  /// local echo (or flags it control so a receipt never renders as a bubble)
  /// and returns it. Does not touch any conversation.
  Future<Envelope> _sendPayload(
    String recipientPubKey,
    String plaintext, {
    bool control = false,
  }) async {
    final envelope = await processor.sendText(
      recipientXPubKey: recipientPubKey,
      plaintext: plaintext,
    );
    if (control) {
      await dao.markControl(envelope.id);
    } else {
      _sentPlaintext[envelope.id] = plaintext;
      await _maybeStoreOutgoing(envelope.id, plaintext, envelope.timestamp);
    }
    return envelope;
  }

  Future<void> _maybeStoreOutgoing(
    String id,
    String plaintext,
    int ts,
  ) async {
    if (!storeOutgoing()) return;
    await dao.putBody(id, plaintext: plaintext, timestamp: ts);
  }

  /// Creates a group with [title] and invites [memberPeerKeys] (X25519; the
  /// device itself is always a member). Returns the new conversation id.
  /// Bounds the roster at [maxGroupMembers] and the title at
  /// [maxGroupTitleLength].
  Future<String> createGroup({
    required String title,
    required List<String> memberPeerKeys,
    required int ts,
  }) async {
    final roster = <String>{myXPubKey, ...memberPeerKeys};
    if (roster.length > maxGroupMembers) {
      throw ArgumentError.value(
        roster.length,
        'members',
        'exceeds maxGroupMembers $maxGroupMembers',
      );
    }
    for (final key in roster) {
      if (!isHexOfLength(key, 32)) {
        throw ArgumentError.value(key, 'members', 'is not a 32-byte hex key');
      }
    }
    final clamped = title.length > maxGroupTitleLength
        ? title.substring(0, maxGroupTitleLength)
        : title;
    final id = _newGroupId();
    await conversationDao.createGroup(
      id: id,
      memberKeys: roster.toList(growable: false),
      title: clamped,
      ts: ts,
      adminKeys: [myXPubKey],
    );
    await _refreshConversations();
    // Tell the invitees the full roster immediately; otherwise they would only
    // learn about each other from the first message that happens to reach them.
    await _sendGroupSync(id, 'c', '', control: true);
    _notifyChange();
    return id;
  }

  static String _newGroupId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Sends [text] to every member of the group (one copy per member, no 1:1
  /// conversations are created by group copies). All copies share one
  /// correlation id so they collapse into a single bubble and their delivery
  /// statuses aggregate.
  Future<void> sendGroupText({
    required String conversationId,
    required String text,
    QuoteRef? quote,
  }) =>
      _sendGroupContainer(
        conversationId,
        kind: GroupContainerKind.message,
        text: text,
        quote: quote,
      );

  /// Publishes a new group title to every member, so renames propagate.
  Future<void> sendGroupTitle({
    required String conversationId,
    required String title,
  }) =>
      _sendGroupContainer(
        conversationId,
        kind: GroupContainerKind.title,
        text: title,
      );

  Future<void> _sendGroupContainer(
    String conversationId, {
    required GroupContainerKind kind,
    required String text,
    QuoteRef? quote,
  }) async {
    final conversation = _conversations[conversationId];
    if (conversation == null || !conversation.isGroup) return;
    final container = switch (kind) {
      GroupContainerKind.message => MessagePayload.composeGroupMessage(
          conversationId: conversationId,
          corrId: _newGroupId(),
          senderX: myXPubKey,
          text: text,
          quote: quote,
        ),
      GroupContainerKind.title => MessagePayload.composeGroupTitle(
          conversationId: conversationId,
          senderX: myXPubKey,
          title: text,
        ),
      GroupContainerKind.roster => throw UnsupportedError(
          'roster events use _sendGroupSync',
        ),
    };
    var lastTs = conversation.lastTs;
    for (final member in conversation.memberKeys) {
      if (member == myXPubKey) continue;
      final envelope = await _sendPayload(member, container);
      if (envelope.timestamp > lastTs) lastTs = envelope.timestamp;
    }
    await conversationDao.setLastTs(conversationId, lastTs);
    await _refreshConversations();
    _notifyChange();
  }

  /// Renders a chunked-file manifest: the finished bubble when the blob has
  /// been assembled (or cached on the sender), otherwise a progress tile once
  /// at least one slice has been validated.
  Future<UiMessage?> _renderFileManifest(
    Envelope envelope,
    FileManifestPayload payload,
    MessageStatus? status, {
    required bool outgoing,
  }) async {
    final senderX = outgoing
        ? myXPubKey
        : (peerByEdPubKey(envelope.senderPubKey)?.pubKey ?? '');
    final stored = await mediaDao.get(payload.manifest.blobId);
    if (stored != null) {
      return UiMessage(
        id: envelope.id,
        outgoing: outgoing,
        timestamp: envelope.timestamp,
        body: '',
        corrId: payload.corrId,
        status: outgoing ? status : null,
        quote: payload.quote,
        senderX: senderX,
        media: MediaAttachment(
          blobId: stored.blobId,
          kind: stored.kind,
          mime: stored.mime,
          byteCount: stored.byteCount,
          durationMs: stored.durationMs,
          dataBase64: stored.dataBase64,
          filePath: stored.filePath,
        ),
      );
    }
    if (outgoing) {
      // Our own send is still in flight; the composer banner carries the
      // progress, there is nothing to render in the list yet.
      return null;
    }
    final transfer = await transferDao.get(payload.manifest.transferId);
    if (transfer == null) return null;
    final received = await transferDao.receivedBytes(
      payload.manifest.transferId,
    );
    return UiMessage(
      id: envelope.id,
      outgoing: false,
      timestamp: envelope.timestamp,
      body: '',
      corrId: payload.corrId,
      quote: payload.quote,
      senderX: senderX,
      transfer: TransferInfo(
        transferId: transfer.transferId,
        kind: payload.kind,
        mime: payload.manifest.mime,
        byteCount: payload.manifest.byteCount,
        receivedBytes: received,
        durationMs: payload.manifest.durationMs,
        started: transfer.started,
        senderOnline: peerByEdPubKey(envelope.senderPubKey)?.online ?? false,
        isGroup: payload.conversationId.isNotEmpty,
      ),
    );
  }

  /// Resolves a parsed media container into a [MediaAttachment], caching the
  /// bytes in storage (idempotent: the content address makes a repeat write a
  /// no-op). Returns `null` when the bytes cannot be materialized — an
  /// inconsistent container never renders as a half bubble.
  Future<MediaAttachment?> _attachMedia(MediaPayload payload) async {
    final cached = await mediaDao.get(payload.blobId);
    if (cached == null) {
      await mediaDao.put(
        blobId: payload.blobId,
        kind: payload.kind,
        mime: payload.mime,
        byteCount: payload.byteCount,
        durationMs: payload.durationMs,
        dataBase64: payload.dataBase64,
        timestamp: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    }
    return MediaAttachment(
      blobId: payload.blobId,
      kind: payload.kind,
      mime: payload.mime,
      byteCount: payload.byteCount,
      durationMs: payload.durationMs,
      dataBase64: payload.dataBase64,
    );
  }

  /// The cached bytes of [blobId], or `null` when never seen or pruned. Used
  /// by the UI to re-render a bubble whose envelope is already gone.
  Future<StoredMedia?> mediaBlob(String blobId) => mediaDao.get(blobId);

  /// Sends a file of any accepted size up to [maxTransferBytes] as a manifest
  /// plus 64 KiB slices (roadmap T-80). A 1:1 chat gets one envelope per
  /// slice; a group fans the manifest and the slices out to every member.
  ///
  /// [onProgress] receives the number of slices handed to the processor and
  /// the total. [cancel] stops between slices and throws [TransferCancelled];
  /// slices already queued and validated by the receiver stay on disk, so a
  /// retry of the same transfer resumes instead of starting over.
  Future<void> sendFileToConversation({
    required String conversationId,
    required MediaKind kind,
    required String mime,
    Uint8List? bytes,
    String? path,
    required int durationMs,
    QuoteRef? quote,
    TransferCancel? cancel,
    void Function(int sent, int total)? onProgress,
    int? maxBytes,
  }) async {
    if ((bytes == null) == (path == null)) {
      throw ArgumentError('Pass exactly one of bytes or path');
    }
    final limit = maxBytes ?? maxTransferBytes;
    final source = path == null ? null : File(path);
    final int byteCount;
    final String sha256;
    if (source != null) {
      if (!await source.exists()) throw ArgumentError('File does not exist');
      byteCount = await source.length();
      sha256 = await _contentAddressFile(source);
    } else {
      if (bytes == null || bytes.isEmpty) throw ArgumentError('File is empty');
      byteCount = bytes.length;
      sha256 = await _contentAddress(bytes);
    }
    if (byteCount == 0) throw ArgumentError('File is empty');
    if (byteCount > limit) {
      throw ArgumentError('File exceeds the $limit-byte transfer limit');
    }
    if (!canSendTo(conversationId)) {
      throw ArgumentError('Conversation $conversationId is not writable');
    }

    final store = mediaDao.store;
    final blobId = sha256;
    final small = byteCount <= maxMediaBlobBytes;
    Uint8List? inline;
    if (small) {
      inline = bytes ?? await source!.readAsBytes();
    } else if (source != null) {
      await store.importBlob(blobId, source);
    } else {
      await store.writeBlob(blobId, Stream<List<int>>.value(bytes!));
    }
    final chunkCount = (byteCount + transferChunkBytes - 1) ~/
        transferChunkBytes;
    final manifest = ChunkManifest(
      transferId: _newTransferId(),
      blobId: blobId,
      kind: kind.name,
      mime: mime,
      byteCount: byteCount,
      chunkSize: transferChunkBytes,
      chunkCount: chunkCount,
      sha256: sha256,
      durationMs: durationMs,
    );

    final isGroupConversation = isGroup(conversationId);
    final List<String> targets;
    var corrId = '';
    if (isGroupConversation) {
      final conversation = _conversations[conversationId];
      if (conversation == null || !conversation.isGroup) {
        throw ArgumentError('Conversation $conversationId is not a group');
      }
      targets = [
        for (final member in conversation.memberKeys)
          if (member != myXPubKey) member,
      ];
      corrId = _newGroupId();
    } else {
      final peer = peerByEdPubKey(conversationId);
      targets = [peer?.pubKey ?? conversationId];
    }
    if (targets.isEmpty) throw ArgumentError('Conversation has no recipients');

    final manifestContainer = isGroupConversation
        ? MessagePayload.composeFileManifestGroup(
            conversationId: conversationId,
            corrId: corrId,
            senderX: myXPubKey,
            manifest: manifest,
            quote: quote,
          )
        : MessagePayload.composeFileManifestDirect(
            senderX: myXPubKey,
            manifest: manifest,
            quote: quote,
          );
    final pushSlices = byteCount <= senderPushBytes;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    // Keep the manifest locally too: a large file is served from this row
    // when a recipient asks for slices. It also makes the request/entitlement
    // check in `_acceptFileRequest` uniform for sender and receiver.
    await transferDao.putManifest(
      StoredTransfer(
        transferId: manifest.transferId,
        blobId: blobId,
        kind: kind,
        mime: mime,
        byteCount: byteCount,
        chunkSize: manifest.chunkSize,
        chunkCount: chunkCount,
        sha256: sha256,
        durationMs: durationMs,
        senderX: myXPubKey,
        conversationId: isGroupConversation ? conversationId : '',
        started: false,
        completed: true,
        timestamp: now,
      ),
    );
    // The sender always keeps its own copy before queuing anything: it is the
    // seed for recipients, and a cancelled send stays readable here.
    if (inline != null) {
      await mediaDao.put(
        blobId: blobId,
        kind: kind,
        mime: mime,
        byteCount: byteCount,
        durationMs: durationMs,
        dataBase64: base64Encode(inline),
        timestamp: now,
      );
    } else {
      await mediaDao.putFile(
        blobId: blobId,
        kind: kind,
        mime: mime,
        byteCount: byteCount,
        durationMs: durationMs,
        path: 'blobs/$blobId',
        timestamp: now,
      );
    }

    var lastTs = 0;
    for (final target in targets) {
      final envelope = await _sendMediaPayload(target, manifestContainer);
      if (envelope.timestamp > lastTs) lastTs = envelope.timestamp;
    }
    final total = chunkCount * targets.length;
    var sent = 0;
    if (pushSlices) {
      final raf = inline == null
          ? await (await store.blobFile(blobId)).open()
          : null;
      try {
        for (var index = 0; index < chunkCount; index++) {
          if (cancel?.isCancelled ?? false) throw const TransferCancelled();
          final start = index * transferChunkBytes;
          final length = (start + transferChunkBytes) > byteCount
              ? byteCount - start
              : transferChunkBytes;
          final Uint8List data;
          if (inline != null) {
            data = Uint8List.sublistView(inline, start, start + length);
          } else {
            await raf!.setPosition(start);
            data = await raf.read(length);
          }
          final digest = await Sha256().hash(data);
          final chunk = FileChunk(
            transferId: manifest.transferId,
            index: index,
            dataBase64: base64Encode(data),
            sha256: _hexOf(digest.bytes),
          );
          for (final target in targets) {
            if (cancel?.isCancelled ?? false) throw const TransferCancelled();
            final container = isGroupConversation
                ? MessagePayload.composeFileChunkGroup(
                    conversationId: conversationId,
                    senderX: myXPubKey,
                    chunk: chunk,
                  )
                : MessagePayload.composeFileChunkDirect(
                    senderX: myXPubKey,
                    chunk: chunk,
                  );
            await _sendChunkPayload(target, container);
            sent++;
            onProgress?.call(sent, total);
          }
        }
      } finally {
        await raf?.close();
      }
    }
    if (isGroupConversation) {
      final conversation = _conversations[conversationId];
      final newTs = conversation != null && conversation.lastTs > lastTs
          ? conversation.lastTs
          : lastTs;
      await conversationDao.setLastTs(conversationId, newTs);
      await _refreshConversations();
    } else {
      await _noteChat(targets.first, lastTs == 0 ? now : lastTs);
    }
    _notifyChange();
  }

  /// Hands one transfer slice to the processor and flags it control locally,
  /// so it never renders as a bubble. A transient failure is retried twice;
  /// a duplicate envelope is harmless because the receiver dedupes both the
  /// envelope id and the chunk index.
  Future<Envelope> _sendChunkPayload(
    String recipientPubKey,
    String plaintext,
  ) async {
    var attempt = 0;
    while (true) {
      try {
        return await _sendMediaPayload(
          recipientPubKey,
          plaintext,
          directOnly: true,
          control: true,
          remember: false,
        );
      } catch (_) {
        attempt++;
        if (attempt >= 3) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  /// A fresh 32-byte transfer id, hex.
  String _newTransferId() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Composes a voice note or photo and sends it to a conversation. A group
  /// message fans out one copy per member sharing a correlation id; a 1:1
  /// chat sends a single envelope. The bytes are cached locally under their
  /// content address so a re-render survives pruning.
  ///
  /// Throws [ArgumentError] when the blob exceeds [maxMediaBlobBytes] or the
  /// conversation cannot be written to; nothing is sent in that case.
  Future<void> sendMediaToConversation({
    required String conversationId,
    required MediaKind kind,
    required String mime,
    required String dataBase64,
    required int durationMs,
    QuoteRef? quote,
  }) async {
    final bytes = _decodeMedia(dataBase64);
    if (bytes.length > maxMediaBlobBytes) {
      throw ArgumentError(
        'Media blob exceeds the $maxMediaBlobBytes-byte limit',
      );
    }
    if (!canSendTo(conversationId)) {
      throw ArgumentError('Conversation $conversationId is not writable');
    }
    final blobId = await _contentAddress(bytes);
    final byteCount = bytes.length;

    if (isGroup(conversationId)) {
      await _sendGroupMedia(
        conversationId,
        blobId: blobId,
        kind: kind,
        mime: mime,
        byteCount: byteCount,
        durationMs: durationMs,
        dataBase64: dataBase64,
        quote: quote,
      );
      return;
    }

    final peer = peerByEdPubKey(conversationId);
    final recipient = peer?.pubKey ?? conversationId;
    final container = MessagePayload.composeMediaDirect(
      senderX: myXPubKey,
      blobId: blobId,
      kind: kind,
      mime: mime,
      byteCount: byteCount,
      durationMs: durationMs,
      dataBase64: dataBase64,
      quote: quote,
    );
    final envelope = await _sendMediaPayload(recipient, container);
    await _cacheSentMedia(
      blobId: blobId,
      kind: kind,
      mime: mime,
      byteCount: byteCount,
      durationMs: durationMs,
      dataBase64: dataBase64,
      ts: envelope.timestamp,
    );
    await _noteChat(recipient, envelope.timestamp);
    _notifyChange();
  }

  Future<void> _sendGroupMedia(
    String conversationId, {
    required String blobId,
    required MediaKind kind,
    required String mime,
    required int byteCount,
    required int durationMs,
    required String dataBase64,
    QuoteRef? quote,
  }) async {
    final conversation = _conversations[conversationId];
    if (conversation == null || !conversation.isGroup) return;
    final container = MessagePayload.composeMediaGroup(
      conversationId: conversationId,
      corrId: _newGroupId(),
      senderX: myXPubKey,
      blobId: blobId,
      kind: kind,
      mime: mime,
      byteCount: byteCount,
      durationMs: durationMs,
      dataBase64: dataBase64,
      quote: quote,
    );
    var lastTs = conversation.lastTs;
    for (final member in conversation.memberKeys) {
      if (member == myXPubKey) continue;
      final envelope = await _sendMediaPayload(member, container);
      if (envelope.timestamp > lastTs) lastTs = envelope.timestamp;
    }
    await _cacheSentMedia(
      blobId: blobId,
      kind: kind,
      mime: mime,
      byteCount: byteCount,
      durationMs: durationMs,
      dataBase64: dataBase64,
      ts: lastTs,
    );
    await conversationDao.setLastTs(conversationId, lastTs);
    await _refreshConversations();
    _notifyChange();
  }

  /// Low-level media send: builds the envelope through the byte-level path
  /// (media is binary), remembers the container for the local echo and caches
  /// the blob. Never touches a conversation.
  Future<Envelope> _sendMediaPayload(
    String recipientPubKey,
    String plaintext, {
    bool directOnly = false,
    bool control = false,
    bool remember = true,
  }) async {
    final envelope = await processor.sendMedia(
      recipientXPubKey: recipientPubKey,
      plaintext: plaintext,
      directOnly: directOnly,
      control: control,
    );
    if (remember) {
      _sentPlaintext[envelope.id] = plaintext;
      await _maybeStoreOutgoing(envelope.id, plaintext, envelope.timestamp);
    }
    return envelope;
  }

  /// Caches a media blob locally so the bubble survives the pruning of the
  /// envelope. Idempotent: the content address makes a repeat write a no-op.
  Future<void> _cacheSentMedia({
    required String blobId,
    required MediaKind kind,
    required String mime,
    required int byteCount,
    required int durationMs,
    required String dataBase64,
    required int ts,
  }) async {
    await mediaDao.put(
      blobId: blobId,
      kind: kind,
      mime: mime,
      byteCount: byteCount,
      durationMs: durationMs,
      dataBase64: dataBase64,
      timestamp: ts,
    );
  }

  /// The content address of a media blob: SHA-256 of the raw bytes, hex. Two
  /// copies of the same file share it, so a fan-out stores the bytes once.
  static Future<String> _contentAddress(List<int> bytes) async {
    final digest = await Sha256().hash(bytes);
    return _hexOf(digest.bytes);
  }

  static Future<String> _contentAddressFile(File file) async {
    final sink = Sha256().newHashSink();
    await for (final chunk in file.openRead()) {
      sink.add(chunk);
    }
    sink.close();
    final digest = await sink.hash();
    return _hexOf(digest.bytes);
  }

  static String _hexOf(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  /// Decodes base64 media strictly; a malformed blob is a caller error, not a
  /// silent empty send.
  static List<int> _decodeMedia(String dataBase64) {
    try {
      return base64Decode(dataBase64);
    } on FormatException {
      throw ArgumentError('Media data is not valid base64');
    }
  }

  /// Routes a composer send to a 1:1 chat or a group by conversation kind.
  /// A DM conversation keyed by a stale Ed25519 key resolves to the peer's
  /// X25519 address before encrypting, so a reply can never go to the wrong
  /// key. Returns `false` (and composes nothing) when the chat is not
  /// attributable to a known peer — the reply could never be encrypted to
  /// the real recipient, so the message would silently vanish.
  Future<bool> sendToConversation({
    required String conversationId,
    required String text,
    QuoteRef? quote,
  }) async {
    if (!canSendTo(conversationId)) return false;
    if (isGroup(conversationId)) {
      await sendGroupText(
        conversationId: conversationId,
        text: text,
        quote: quote,
      );
      return true;
    }
    final peer = peerByEdPubKey(conversationId);
    await sendText(
      recipientPubKey: peer?.pubKey ?? conversationId,
      plaintext: text,
      quote: quote,
    );
    return true;
  }

  /// Whether a chat can be written to. Groups always can. A 1:1 chat is
  /// writable only when its key is attributable to a known peer: either it is
  /// already that peer's X25519 address, or it maps through a learned
  /// Ed25519→X25519 binding. A chat keyed by an unbound key (an unknown
  /// sender's Ed25519 address) cannot be answered until the peer is imported,
  /// because the device has no X25519 address to encrypt the reply to.
  bool canSendTo(String conversationId) {
    final conversation = _conversations[conversationId];
    if (conversation != null && conversation.isGroup) {
      return conversation.memberKeys.contains(myXPubKey);
    }
    return _peers.containsKey(conversationId) ||
        peerByEdPubKey(conversationId) != null;
  }

  Future<bool> isGroupAdmin(String conversationId) async {
    if (!isGroup(conversationId)) return false;
    return conversationDao.isAdmin(conversationId, myXPubKey);
  }

  Future<List<({String key, String role})>> groupMembers(
    String conversationId,
  ) =>
      conversationDao.membersWithRoles(conversationId);

  /// Adds [key] to the group and broadcasts the new roster. Admin-only; the
  /// roster ceiling is enforced by the DAO.
  Future<bool> addGroupMember(String conversationId, String key) async {
    if (!isHexOfLength(key, 32)) return false;
    if (!await isGroupAdmin(conversationId)) return false;
    try {
      await conversationDao.addMember(conversationId, key);
    } on ArgumentError {
      return false;
    }
    await _refreshConversations();
    await _sendGroupSync(conversationId, 'a', key);
    return true;
  }

  /// Removes [key] and broadcasts the roster to everyone, including the
  /// removed member (so their device turns read-only instead of silently
  /// talking into the void). Refuses to remove the last admin.
  Future<bool> removeGroupMember(String conversationId, String key) async {
    if (!isHexOfLength(key, 32)) return false;
    if (!await isGroupAdmin(conversationId)) return false;
    final bool removed;
    try {
      removed = await conversationDao.removeMember(conversationId, key);
    } on StateError {
      return false;
    }
    if (!removed) return false;
    await _refreshConversations();
    await _sendGroupSync(conversationId, 'r', key);
    return true;
  }

  /// Promotes or demotes [key]; admin-only.
  Future<bool> setGroupMemberRole(
    String conversationId,
    String key,
    String role,
  ) async {
    if (!await isGroupAdmin(conversationId)) return false;
    try {
      await conversationDao.setRole(conversationId, key, role);
    } on ArgumentError {
      return false;
    } on StateError {
      return false;
    }
    await _refreshConversations();
    await _sendGroupSync(
      conversationId,
      role == ConversationDao.adminRole ? 'p' : 'd',
      key,
    );
    return true;
  }

  /// Sends the current roster to every member (and to [target] when it has
  /// just been removed), carrying the action that caused the change so the
  /// recipients can render a system line.
  Future<void> _sendGroupSync(
    String conversationId,
    String action,
    String target, {
    bool control = false,
  }) async {
    final conversation = _conversations[conversationId];
    if (conversation == null || !conversation.isGroup) return;
    final roster = await conversationDao.memberKeys(conversationId);
    final recipients = {
      ...roster,
      if (target.isNotEmpty) target,
      myXPubKey,
    }..remove(myXPubKey);
    final container = MessagePayload.composeGroupRoster(
      conversationId: conversationId,
      senderX: myXPubKey,
      action: action,
      targetKey: target,
      roster: roster,
    );
    var lastTs = conversation.lastTs;
    for (final member in recipients) {
      final envelope = await _sendPayload(member, container, control: control);
      if (envelope.timestamp > lastTs) lastTs = envelope.timestamp;
    }
    await conversationDao.setLastTs(conversationId, lastTs);
    await _refreshConversations();
    _notifyChange();
  }

  /// Unsent envelopes of one 1:1 chat, oldest first.
  ///
  /// Group copies are not attributed to a chat here: one container fans out to
  /// every member, so the chat-level retry panel would double count them.
  Future<List<String>> pendingOutgoing(
    String conversationId, {
    DateTime? now,
    bool includeRecent = false,
  }) async {
    if (isGroup(conversationId)) return const [];
    final ids = await dao.pendingOutboundIds();
    final cutoff = (now ?? DateTime.now())
        .subtract(const Duration(milliseconds: pendingBannerGraceMs))
        .millisecondsSinceEpoch;
    final out = <String>[];
    for (final id in ids) {
      final envelope = await dao.envelopeById(id);
      if (envelope == null || envelope.recipientPubKey != conversationId) {
        continue;
      }
      // Media slices and requests are control frames. They are stored as
      // messages so they can be retried, but they are not chat messages: a
      // still-queued slice must not put a "not delivered" banner under a
      // photo whose read receipt already arrived.
      if (await dao.isControl(id)) continue;
      if (includeRecent || envelope.timestamp <= cutoff) out.add(id);
    }
    return out;
  }

  static const String draftKeyPrefix = 'soty.draft.';

  /// The unsent composer text of [conversationId], or `null`.
  Future<String?> draftFor(String conversationId) =>
      settingsDao.get('$draftKeyPrefix$conversationId');

  /// Persists a draft, bounded by the wire plaintext limit so a pasted blob
  /// cannot grow the settings row without bound. Empty text clears it.
  Future<void> saveDraft(String conversationId, String text) async {
    final key = '$draftKeyPrefix$conversationId';
    if (text.trim().isEmpty) {
      await settingsDao.remove(key);
      return;
    }
    var value = text;
    while (value.isNotEmpty && utf8.encode(value).length > maxPlaintextBytes) {
      value = value.substring(0, value.length - 1);
    }
    await settingsDao.set(key, value);
  }

  Future<void> clearDraft(String conversationId) =>
      settingsDao.remove('$draftKeyPrefix$conversationId');

  Future<List<PrunedRootEntry>> prunedRoots() =>
      prunedRootsDao.getPrunedRoots();

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    // Work started from a stream event outlives that event; it must not
    // outlive the controller, or it would touch a closed database.
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList(growable: false));
    }
    await _tick.close();
  }
}
