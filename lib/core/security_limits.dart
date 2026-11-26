/// Centralized resource limits for hostile-input handling. Every wire read
/// and every list that a remote peer can drive goes through these caps so a
/// hostile node can never exhaust memory or CPU (DoS).
library;

/// Maximum wire size of a single envelope frame. Generous for text-only
/// messages, small enough to defeat memory-exhaustion attacks.
const int maxFrameBytes = 256 * 1024;

/// Maximum UTF-8 size of one plaintext message.
const int maxPlaintextBytes = 4 * 1024;

/// Maximum UTF-8 size of one media container (a voice note or a photo
/// carried in a single envelope). Deliberately separate from
/// [maxPlaintextBytes]: raising the text limit would widen the DoS surface of
/// every ordinary message, while a media container is a different, explicitly
/// bounded payload class.
const int maxMediaPlaintextBytes = 192 * 1024;

/// Maximum raw size of one media file before base64 encoding. Chosen so
/// `base64(blob) + header` always fits under [maxFrameBytes]: 128 KiB of data
/// becomes ~171 KiB of base64, which is comfortably below the 256 KiB frame
/// cap on every transport (p2p stream, relay websocket, mesh).
const int maxMediaBlobBytes = 128 * 1024;

/// Envelopes one media item is carried in. Phase one is single-envelope; a
/// chunked multi-envelope form would raise this, and every consumer must keep
/// treating it as a hard bound.
const int maxMediaChunks = 1;

/// Voice recording bounds: the announced ceiling the recorder counts down to,
/// and the shortest take still worth sending.
const int maxVoiceMs = 30 * 1000;
const int minVoiceMs = 500;

/// Media kinds that carry a duration; a photo has none.
const List<String> mediaVoiceKinds = ['voice'];

/// Media kinds and their accepted MIME prefixes. A container claiming
/// anything outside this list is treated as plain text rather than trusted.
const List<String> mediaPhotoKind = ['photo'];
const List<String> mediaAudioMimePrefixes = ['audio/'];
const List<String> mediaVideoMimeTypes = [
  'video/mp4',
  'video/webm',
  'video/quicktime',
];

const List<String> mediaImageMimeTypes = [
  'image/jpeg',
  'image/png',
  'image/webp',
];

/// Longest accepted MIME type string in a media container.
const int maxMediaMimeLength = 128;

/// Maximum number of ids per gossip HAVE/GET and envelopes per ENVELOPES.
const int maxGossipItems = 256;

/// Maximum outbound gossip frames buffered before older frames are dropped.
const int maxGossipQueue = 64;

/// Upper bound (ms) for a `since` scan window; earlier windows are clamped.
const int gossipMaxScanWindow = 30 * 24 * 60 * 60 * 1000;

/// Per-transport dedup key ceiling; the oldest keys are evicted (FIFO).
const int maxSeenIds = 4096;

/// Maximum envelope ids carried by a single delivery/read receipt. A receipt
/// is only ever an acknowledgement, so a hostile flood of ids is clamped.
const int maxReceiptIds = 256;

/// Display-name / capabilities length ceilings.
const int maxDisplayNameLength = 64;
const int maxCapabilities = 16;

/// Multiple-address ceiling per peer.
const int maxPeerAddrs = 8;

/// Future clock-skew tolerated for envelopes and identity claims.
const Duration maxClockSkew = Duration(minutes: 5);

/// How old an identity claim may get before it is considered expired
/// (invites stay valid across months, so this is deliberately generous).
const Duration maxClaimAge = Duration(days: 90);

/// App-lock password bounds. The floor keeps weak PINs out; the ceiling
/// bounds the PBKDF2 work a hostile local input can force.
const int minAppLockPasswordLength = 6;
const int maxAppLockPasswordLength = 128;

/// PBKDF2-HMAC-SHA256 work factor and output width for the stored
/// app-lock password verifier.
const int minAppLockPbkdf2Iterations = 1000;
const int appLockPbkdf2Iterations = 210000;
const int maxAppLockPbkdf2Iterations = appLockPbkdf2Iterations * 8;
const int appLockSaltBytes = 16;
const int appLockHashBytes = 32;

/// When a biometric unlock succeeds the system prompt makes the activity
/// briefly background; resumes within this window are not treated as a new
/// backgrounding so the app does not instantly re-lock.
const int biometricResumeLockGraceMs = 2000;

/// Maximum number of relay hosts a client subscribes to at once.
const int maxHosts = 8;

/// Cap on subscription keys per host connection (a client subscribes with
/// its own keys only).
const int maxHostSubscriptionKeys = 16;

/// How long a host keeps an envelope whose recipient is not currently
/// subscribed to it (relay window, ms).
const int hostRelayWindowMs = 24 * 60 * 60 * 1000;

/// Default host retention (ms), used for the age-based prune.
const int hostRetentionMs = 30 * 24 * 60 * 60 * 1000;

/// Host-to-host gossip hop ceiling. Frames beyond it are not re-relayed.
const int hostGossipMaxHops = 3;

/// Rate-limit bucket window (seconds) and envelope budget per sender per
/// window; the bucket table is capped at [maxRateLimiterKeys] senders.
const int hostRateWindowSeconds = 60;
const int hostRateLimitPerWindow = 60;

/// Live (never stored) slice budget per sender per window. A media slice is
/// ~87 KB of base64, so a photo is dozens of frames and a multi-megabyte file
/// hundreds. Counting them against the stored-envelope budget would throttle
/// every real transfer, while still bounding relay bandwidth per sender.
const int hostRateLimitLivePerWindow = 1200;
const int maxRateLimiterKeys = 2048;

/// Backfill rounds one SUBSCRIBE answer may spend before the host gives up
/// on the remainder — a hostile cursor cannot stall the connection forever.
const int hostBackfillMaxRounds = 16;

/// Hard cap on the envelopes reported by one WANT/HAVE sync exchange.
const int hostMaxSyncEnvelopes = 4096;

/// Peers a tracker may hand out in one PEER_LIST answer.
const int maxTrackerPeers = 64;

/// Tracker-advertised relays per PEER_LIST. Mirrors the host network bound
/// ([maxFederatedHosts]) so a client learns every relay its host knows; the
/// client pool itself stays capped by [maxHosts].
const int maxTrackerHosts = 32;

/// Ceiling on the members one NETWORK federation-gossip frame may carry
/// (host↔host topology: the sender itself plus every member it knows).
const int maxFederatedHosts = 32;

/// Devices one PRESENCE feed may list as online (the keys a host currently
/// has subscribed). A busy relay truncates the oldest subscriptions first.
const int maxPresenceKeys = 64;

/// Hard cap on simultaneous WebSocket connections a relay accepts. Each
/// connection holds a socket plus up to [maxHostSubscriptionKeys] keys, so an
/// unbounded count is a trivial memory/descriptor DoS.
const int maxHostConnections = 512;

/// Ceiling on remembered subscription keys in `host.db`; the oldest rows are
/// evicted beyond it.
const int maxHostSubscriptionRows = 100000;

/// How long a relay keeps an idle WebSocket open when the peer stops
/// answering protocol pings.
const Duration hostIdleTimeout = Duration(minutes: 5);

/// Age policy for envelopes a device only relays for someone else (neither
/// sent nor received by this identity): never kept longer than this, no
/// matter the user's own retention setting.
const int relayedCacheWindowMs = 30 * 24 * 60 * 60 * 1000;

/// Byte ceiling for that relayed cache; past it the oldest relayed rows are
/// pruned first (the 10 GiB bound on forwarded-for-others storage).
const int relayedCacheMaxBytes = 10 * 1024 * 1024 * 1024;

/// Day counts offered in the "keep messages" picker; 0 stands for "keep
/// forever". The default mirrors the historical fixed 30-day prune.
const List<int> retentionOptionsDays = [7, 30, 90, 180, 365, 0];

/// Settings key holding the user's own-conversation retention in days
/// (0 = forever).
const String retentionSettingsKey = 'soty.retentionDays';


/// Per-peer address ceiling on the wire (HELLO myAddrs, PEER_LIST refs).
const int maxPeerAddrsOnWire = 8;

/// Upper length bound for one multiaddr string on the wire.
const int maxAddrLength = 256;

/// Upper length bound for a libp2p PeerId string on the wire.
const int maxPeerIdLength = 128;

/// Default / ceiling for the configurable active-peers pool (P2P).
const int maxActivePeersDefault = 25;
const int maxActivePeersCeiling = 50;

/// Once this many peers are known, a client stops asking trackers for peers
/// (trackers remain a hosts source; the mailbox relay stays live).
const int trackerStopPeerListCount = 8;

/// How many auto-detected LAN multiaddrs a device advertises for direct dial.
/// Kept small on purpose: peers try each address in order, and a long list of
/// stale home-network addresses only slows an actual dial down.
const int maxAdvertisedLanAddrs = 4;

/// Consecutive failed connects before a host is dropped from the pool.
const int hostPoolMaxFailures = 4;

/// How long a tracker remembers a peer that has not refreshed itself.
const int hostTrackerPeerTtlMs = 24 * 60 * 60 * 1000;

/// Hard cap on tracker-known peers; the oldest are evicted beyond it.
const int maxKnownPeers = 8192;

/// Hard ceiling on envelopes a RAM-first relay keeps. The OpenWrt
/// `dtm_relay` (`relay-owrt/`) defaults to RAM because router flash wears
/// out, and a 30-day retention is meaningless in 128 MiB of RAM. Beyond
/// this count or [hostMaxStoredBytes] the oldest rows are evicted first;
/// signed prune roots cover only age/subscription pruning, so cap eviction
/// is a cache drop, not a retention promise. A server-side `dtm_host` does
/// not apply this cap; the router implementation mirrors it in
/// `relay-owrt/internal/limits`.
const int hostMaxStoredEnvelopes = 20000;
const int hostMaxStoredBytes = 32 * 1024 * 1024;

/// Maximum members in one group chat (roster incl. self).
const int maxGroupMembers = 512;

/// Maximum group chats a device keeps. Each group is a row plus one member row
/// per participant, so an unbounded count is a slow local DoS once peer-
/// announced groups are accepted.
const int maxGroupCount = 256;

/// Maximum length of a user-set chat/group title.
const int maxGroupTitleLength = 64;

/// Messages one chat page holds. Opening a chat renders this many newest
/// bubbles; older history is fetched a page at a time as the user scrolls up.
const int messagePageSize = 50;

/// Maximum length of the one-line quote preview carried with a reply. Keeps
/// bubbles small even if a hostile sender provides a long snippet.
const int maxQuotePreviewChars = 160;

/// Most recently used emoji the picker remembers. Bounds the stored recent
/// list so it can never grow without limit.
const int maxEmojiRecents = 64;

/// Update check: the release metadata comes from a remote server, so the
/// response is read with the same suspicion as any other hostile input.
///
/// Longest accepted `major.minor.patch+build` version string.
const int maxVersionStringLength = 32;

/// Byte ceiling for the GitHub "latest release" JSON document.
const int maxUpdateMetadataBytes = 256 * 1024;

/// Byte ceiling for a downloaded update APK. The shipped app is far smaller;
/// the cap only stops a lying `content-length` from filling the disk.
const int maxUpdateApkBytes = 200 * 1024 * 1024;

/// Longest accepted download URL in the release metadata.
const int maxUpdateAssetUrlLength = 2048;

/// Longest release-notes excerpt kept for display.
const int maxUpdateNotesChars = 4000;

/// Network timeout for the release metadata and for one download chunk read.
const Duration updateRequestTimeout = Duration(seconds: 20);

/// Most unsent outgoing envelopes one retry pass re-dispatches. Bounds the
/// work a long offline stretch can queue up on the next reconnect.
const int maxPendingOutbound = 256;

/// How long a freshly queued message is still treated as in flight before the
/// chat shows the "not delivered yet" banner. Without this, every normal send
/// flashes a red banner while the transport is still acknowledging it.
const int pendingBannerGraceMs = 10000;

/// Ceiling on the session plaintext caches (our own sent bodies and decrypted
/// inbound bodies). Chat history is read from storage; these maps only spare a
/// repeated decryption for what is currently on screen.
const int maxPlaintextCacheEntries = 512;

/// Largest accepted backup document (identity + contacts, base64 inside).
/// Checked on the raw string before any JSON parse.
const int maxBackupBytes = maxBackupUploadBytes;

/// Peers a backup may carry. The live book is capped at
/// [maxActivePeersCeiling], so a file above that is hostile.
const int maxBackupPeers = maxActivePeersCeiling;

/// Shortest password a new backup may be sealed with.
const int minBackupPasswordLength = 8;

/// Longest accepted backup password, in UTF-16 code units. Bounded so a
/// hostile import file cannot feed an unbounded string into the KDF.
const int maxBackupPasswordLength = 1024;

/// Argon2id parameters written by this build. A backup that asks for anything
/// else is rejected before any memory is allocated.
const int backupKdfMemoryKib = 64 * 1024;
const int backupKdfIterations = 3;
const int backupKdfParallelism = 1;
const int backupSaltBytes = 16;
const int backupNonceBytes = 12;
const int backupTagBytes = 16;

/// Newest messages the in-memory search index decrypts. Bounded so a huge
/// history cannot turn a query into an unbounded CPU/memory job.
const int maxSearchIndexMessages = 10000;

/// Rows a single search query returns.
const int maxSearchResults = 100;

/// Conversations and messages a backup may carry.
const int maxBackupConversations = 200;
const int maxBackupMessages = 20000;

/// Largest accepted backup file on the wire (encrypted, base64-heavy).
const int maxBackupUploadBytes = 1024 * 1024 * 1024;

/// Upper bound for any timestamp read off the wire (2100-01-01 UTC). Keeps a
/// hostile "last seen in year 5000" from becoming a permanent peer record.
const int maxReasonableTimestamp = 4102444800000;

/// How long the outbound pipeline waits for one transport before treating it
/// as a miss and letting the others (relay, mesh) carry the envelope. A stalled
/// p2p dial used to serialize behind the relay and leave "sending" for ~30 s.
const Duration transportSendTimeout = Duration(seconds: 6);

/// A file slice is a ~87 KiB base64 frame and takes far longer than a text
/// message over BLE. Bulk frames get their own, generous budget instead of
/// being cancelled while the radio is still writing.
const Duration transportBulkSendTimeout = Duration(seconds: 120);

/// Direct-first probe for a media slice. One p2p attempt per recipient is
/// raced against this deadline; if it does not connect, the slices fall back
/// to the live relay for [directProbeCooldown]. Without the gate every slice
/// pays the full dial timeout and a 2 MB file takes minutes.
const Duration directProbeTimeout = Duration(seconds: 4);
const Duration directProbeCooldown = Duration(seconds: 20);

/// Largest file a chunked transfer may carry. The bound is defensive, not a
/// product limit: the real constraint is the device's free space.
const int maxTransferBytes = 2 * 1024 * 1024 * 1024;

/// Files up to this size start downloading automatically. A larger file waits
/// for an explicit tap, so a 1 GB video never consumes data behind the user's
/// back (roadmap T-80).
const int autoDownloadBytes = 100 * 1024 * 1024;

/// The sender only pushes slices for files this small (a few slices). A
/// larger file is announced by its manifest and pulled by the recipient,
/// which is the whole point of the chunked transfer: pushing a 32 MB file
/// re-sent every slice, doubled the traffic and kept the composer's progress
/// banner rebuilding the chat hundreds of times.
const int senderPushBytes = 512 * 1024;

/// Payload bytes per chunk; base64 + header stays well under a frame.
const int transferChunkBytes = 64 * 1024;

/// Chunks a maximal transfer is split into.
const int maxTransferChunks =
    (maxTransferBytes + transferChunkBytes - 1) ~/ transferChunkBytes;

/// Chunk requests a recipient keeps in flight while downloading one file.
const int maxOutstandingChunkRequests = 8;

/// Slices one holder will serve to the same peer at once, so a hostile
/// requester cannot turn the device into an unbounded uploader.
const int maxConcurrentServesPerPeer = 8;

/// Chunked transfers kept in the staging area at once, so a hostile sender
/// cannot make the device hold unbounded partial files (roadmap T-80).
const int maxActiveTransfers = 64;

/// Media bytes cached on this device. Older blobs are pruned first, so a long
/// media history cannot grow storage without bound; an explicit save keeps a
/// copy outside this cache.
const int maxMediaCacheBytes = 4 * 1024 * 1024 * 1024;
