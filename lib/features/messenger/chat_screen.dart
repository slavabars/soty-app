import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/crypto/hex.dart' show isHexOfLength;
import '../../core/i18n/app_prefs.dart';
import '../../core/i18n/soty_l10n.dart';
import '../../core/media/chunked_transfer.dart'
    show TransferCancel, TransferCancelled;
import '../../core/media/media_capture.dart';
import '../../core/media/plugin_media.dart';
import '../../core/notifications/chat_notifications.dart'
    show encryptedPlaceholder;
import '../../core/security_limits.dart'
    show
        maxDisplayNameLength,
        maxMediaBlobBytes,
        maxPlaintextBytes,
        senderPushBytes,
        maxQuotePreviewChars,
        maxTransferBytes,
        messagePageSize,
        minVoiceMs,
        pendingBannerGraceMs;
import '../../core/share/share_service.dart';
import '../../models/message_payload.dart' show MediaKind, MessagePayload, QuoteRef;
import '../../models/message_status.dart';
import '../../models/peer.dart';
import '../settings/scan_qr_screen.dart';
import 'emoji_data.dart';
import 'group_info_screen.dart';
import 'linkified_text.dart';
import 'media_bubble.dart';
import 'messenger_controller.dart';
import 'peer_name_dialog.dart';
import 'peer_presence.dart';
import 'peer_security_screen.dart';
import 'search_screen.dart';

/// Single conversation: read-only message list (text only) + composer. A 1:1
/// chat is keyed by the peer's X25519 address; a group by its 32-byte id,
/// with the online indicator only shown for 1:1 chats.
class ChatScreen extends StatefulWidget {
  final String conversationId;
  final MessengerController messenger;
  final AppPrefs prefs;

  /// Handles a tapped `soty://` link inside a message body; wiring it to the
  /// app's deep-link handling makes an in-message invite tap behave exactly
  /// like opening the link from outside. `null` leaves such taps inert.
  final Future<void> Function(String route)? onSotyLink;

  /// The platform services the composer drives. `null` uses the real
  /// recorder, picker and player; the widget tests inject their own.
  final MediaServices? media;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.messenger,
    required this.prefs,
    this.onSotyLink,
    this.media,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _composer = TextEditingController();
  bool _hasComposerText = false;

  /// Unsent envelopes of this chat; drives the failure banner.
  int _pendingOutgoing = 0;

  /// Debounce for persisting the composer as a draft.
  Timer? _draftTimer;

  final ScrollController _scroll = ScrollController();
  final GlobalKey _anchorKey = GlobalKey();
  List<UiMessage> _messages = const [];
  bool _loading = true;
  StreamSubscription<void>? _changes;

  /// How many newest envelopes a 1:1 chat renders. Grows a page at a time as
  /// the user scrolls towards older history.
  int _pageLimit = messagePageSize;
  bool _loadingOlder = false;

  /// One reload per burst, not one per envelope. While a pass is in flight
  /// further change events only raise [_reloadQueued]; the pass repeats once
  /// when it finishes.
  bool _reloading = false;
  bool _reloadQueued = false;
  bool _followQueued = false;

  /// Checks a queued message again after the grace window, so a genuinely
  /// stuck send still raises the banner once it is no longer in flight.
  Timer? _pendingTimer;

  /// Chat title the current frame was built with. A rename changes no
  /// messages, so the no-op rebuild guard has to watch the title separately or
  /// the app bar keeps the old name.
  String? _renderedTitle;

  /// Inbound messages that were unread when the chat was opened. Counted
  /// before [MessengerController.markConversationRead] moves the read cursor,
  /// and spent on the first reload: the viewport then rests on the first
  /// unread message instead of the tail, which is where reading had stopped.
  int _unreadAtEntry = 0;

  /// True from the first reload until the anchor row has actually been reached.
  /// While it holds, the row keeps [_anchorKey] so [Scrollable.ensureVisible]
  /// has something to align, and later reloads do not drag the viewport to the
  /// tail behind its back.
  bool _anchorPending = false;

  /// How far from the newest message the viewport may sit and still count as
  /// "following along". Roughly a bubble of slack, so a small overscroll or a
  /// half-visible bubble does not read as the user deliberately going back.
  static const double _followThreshold = 48;

  /// One shot latch: the backlog is anchored once per chat, not on every
  /// reload that follows.
  bool _anchorSpent = false;

  /// A follow the anchor seek owes the caller: sending while the backlog is
  /// still being located must land on the newest message, but the jump can
  /// only happen once the anchor is out of the way. Without it the seek's
  /// early return would swallow the send and leave the tail off screen.
  bool _followPending = false;

  /// Row that carries [_anchorKey], resolved once per build so the list stays
  /// linear in the number of messages.
  int? _anchorItem;

  /// Message the composer is answering, if any. Cleared once the reply is
  /// sent or the banner is dismissed.
  UiMessage? _replyingTo;

  /// Whether the emoji panel is open, and which of its tabs is selected
  /// (`0` = recents, then one per [emojiCategories] entry).
  bool _emojiOpen = false;
  int _emojiTab = 1;

  /// The media services the composer drives. The platform ones are built on
  /// first use, so a chat that never touches media never reaches a plugin.
  MediaServices get _media => widget.media ?? _platformMedia;

  static final MediaServices _platformMedia = MediaServices(
    recorder: PluginVoiceRecorder(),
    picker: PluginPhotoPicker(),
    videoPicker: PluginVideoPicker(),
    filePicker: PluginFilePicker(),
    newPlayer: PluginVoicePlayer.new,
  );

  /// Whether the microphone button is held down. It leads the actual
  /// recording state: the recorder needs a moment to warm up, and a button
  /// released in that window must not leave a recording running.
  bool _micPressed = false;

  /// Whether a recording is running right now.
  bool _recording = false;

  /// How long the current take has been running, shown in the banner. There
  /// is no hard cut-off: a long voice note travels as slices like any file.
  int _recordElapsedMs = 0;

  /// A chunked video send in flight: slices handed to the processor, the
  /// total, the cancel token and the label shown in the banner. `null` when
  /// nothing is being sent.
  TransferCancel? _transferCancel;
  int _transferSent = 0;
  int _transferTotal = 0;
  String _transferLabel = '';

  Timer? _recordTimer;
  final Stopwatch _recordWatch = Stopwatch();

  /// How often the countdown is refreshed while recording.
  static const Duration _recordTick = Duration(milliseconds: 200);

  /// Opens the picker on the recents tab when there is something there, else
  /// on the first real category, so it never greets the user with an empty
  /// grid.
  void _toggleEmoji() => setState(() {
    _emojiOpen = !_emojiOpen;
    if (_emojiOpen) {
      _emojiTab = widget.prefs.emojiRecents.isEmpty ? 1 : 0;
    }
  });

  @override
  void initState() {
    super.initState();
    _composer.addListener(_onComposerTextChanged);
    _changes = widget.messenger.onChange.listen((_) => _reload());
    unawaited(_restoreDraft());
    unawaited(_open());
  }

  Future<void> _open() async {
    _unreadAtEntry = await widget.messenger.unreadCountFor(
      widget.conversationId,
    );
    // Land on the first unread message: the page must be wide enough to reach
    // it, otherwise the anchor cannot be located and the chat opens at the
    // tail instead.
    if (_unreadAtEntry > 0) {
      _pageLimit = messagePageSize + _unreadAtEntry;
    }
    if (!mounted) return;
    // Mark read on entry: this chat is now what the user is looking at, so it
    // stops counting as unread and stops asking for a notification. Counting
    // first matters, the cursor overwrites the backlog boundary.
    unawaited(widget.messenger.markConversationRead(widget.conversationId));
    await _reload();
  }

  void _onComposerTextChanged() {
    _draftTimer?.cancel();
    _draftTimer = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_persistDraft()),
    );
    final hasText = _composer.text.trim().isNotEmpty;
    if (hasText == _hasComposerText) return;
    if (!mounted) return;
    setState(() => _hasComposerText = hasText);
  }

  Future<void> _restoreDraft() async {
    final draft = await widget.messenger.draftFor(widget.conversationId);
    if (!mounted || draft == null || draft.isEmpty) return;
    if (_composer.text.isNotEmpty) return;
    _composer.text = draft;
    _composer.selection = TextSelection.collapsed(offset: draft.length);
  }

  Future<void> _persistDraft() async {
    final text = _composer.text;
    if (text.trim().isEmpty) {
      await widget.messenger.clearDraft(widget.conversationId);
    } else {
      await widget.messenger.saveDraft(widget.conversationId, text);
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _pendingTimer?.cancel();
    unawaited(_persistDraft());
    _composer.removeListener(_onComposerTextChanged);
    _changes?.cancel();
    _scroll.dispose();
    widget.messenger.clearVisibleConversation(widget.conversationId);
    super.dispose();
  }

  Future<void> _reload({bool follow = false}) async {
    if (_reloading) {
      _reloadQueued = true;
      _followQueued = _followQueued || follow;
      return;
    }
    _reloading = true;
    try {
      var followNow = follow;
      do {
        _reloadQueued = false;
        final queuedFollow = _followQueued;
        _followQueued = false;
        await _reloadOnce(follow: followNow || queuedFollow);
        followNow = false;
      } while (_reloadQueued && mounted);
    } finally {
      _reloading = false;
    }
  }

  Future<void> _reloadOnce({required bool follow}) async {
    final requestedLimit = _pageLimit;
    final messages = await widget.messenger.messagesFor(
      widget.conversationId,
      limit: requestedLimit,
    );
    // A page-size change while the query was in flight (the user scrolled to
    // the archive) makes this result stale; the newer pass wins.
    if (!mounted || requestedLimit != _pageLimit) return;
    final pending = (await widget.messenger.pendingOutgoing(
      widget.conversationId,
    ))
        .length;
    final anyQueued = (await widget.messenger.pendingOutgoing(
      widget.conversationId,
      includeRecent: true,
    ))
        .length;
    if (!mounted) return;
    if (anyQueued > pending) {
      _schedulePendingCheck();
    } else {
      _pendingTimer?.cancel();
    }
    if (pending != _pendingOutgoing) {
      setState(() => _pendingOutgoing = pending);
    }
    // Every envelope, receipt and presence tick nudges the app to refresh, and
    // an unrelated conversation must not rebuild this list. A cheap structural
    // compare keeps the frame budget of an open chat flat while messages from
    // elsewhere arrive.
    final title = widget.messenger.chatTitle(widget.conversationId);
    final unchanged =
        _sameMessages(_messages, messages) && _renderedTitle == title;
    // Read the resting position before the new list lands: whether to follow
    // depends on where the user was, not on where the new bottom is.
    final stick = follow || _isNearBottom;
    final anchor = _unreadAtEntry;
    if (!unchanged) {
      setState(() {
        _messages = messages;
        _renderedTitle = title;
        _loading = false;
      });
    } else if (_loading) {
      setState(() => _loading = false);
    }
    if (_anchorPending || (anchor > 0 && !_anchorSpent)) {
      // Opening a chat that was left with unread messages: rest there once, so
      // the backlog is read in order rather than skipped to the newest.
      if (_anchorSpent) {
        // A near-bottom read only counts while a list is attached: before the
        // first frame there is no position yet, and guessing "the user is at
        // the tail" from that would drag the backlog to the newest message.
        if (follow || (_scroll.hasClients && _isNearBottom)) {
          _followPending = true;
        }
        return;
      }
      _anchorSpent = true;
      _anchorPending = true;
      setState(() {});
      _scrollToAnchor(messages, anchor);
      return;
    }
    if (stick) _scrollToLatest();
  }

  void _schedulePendingCheck() {
    _pendingTimer?.cancel();
    _pendingTimer = Timer(
      const Duration(milliseconds: pendingBannerGraceMs),
      () {
        if (!mounted) return;
        unawaited(_refreshPendingBanner());
      },
    );
  }

  Future<void> _refreshPendingBanner() async {
    final pending = (await widget.messenger.pendingOutgoing(
      widget.conversationId,
    ))
        .length;
    if (!mounted || pending == _pendingOutgoing) return;
    setState(() => _pendingOutgoing = pending);
  }

  /// Fetches one more page of older history. Called when the oldest rendered
  /// row becomes visible; a short page means the archive is exhausted.
  Future<void> _loadOlder() async {
    if (_loadingOlder || _loading) return;
    _loadingOlder = true;
    try {
      _pageLimit += messagePageSize;
      final messages = await widget.messenger.messagesFor(
        widget.conversationId,
        limit: _pageLimit,
      );
      if (!mounted) return;
      if (_sameMessages(_messages, messages)) return;
      setState(() => _messages = messages);
    } finally {
      _loadingOlder = false;
    }
  }

  /// Whether two rendered lists would look identical: same messages, same
  /// order, same delivery statuses and bodies.
  static bool _sameMessages(List<UiMessage> a, List<UiMessage> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.id != y.id ||
          x.outgoing != y.outgoing ||
          x.status != y.status ||
          x.body != y.body ||
          x.corrId != y.corrId ||
          x.senderX != y.senderX ||
          x.quote?.refId != y.quote?.refId ||
          (x.media == null) != (y.media == null) ||
          x.media?.blobId != y.media?.blobId ||
          (x.transfer == null) != (y.transfer == null) ||
          x.transfer?.transferId != y.transfer?.transferId ||
          x.transfer?.receivedBytes != y.transfer?.receivedBytes ||
          x.transfer?.started != y.transfer?.started) {
        return false;
      }
    }
    return true;
  }

  /// Index of the oldest of the [count] newest inbound messages, or null when
  /// the backlog no longer lines up (history trimmed, or a peer cleared).
  int? _anchorIndex(List<UiMessage> messages, int count) {
    final inbound = <int>[];
    for (var i = 0; i < messages.length; i++) {
      if (!messages[i].outgoing) inbound.add(i);
    }
    final firstUnread = inbound.length - count;
    if (firstUnread < 0 || firstUnread >= inbound.length) return null;
    return inbound[firstUnread];
  }

  /// Rendered row of the oldest unread inbound message, or null when the
  /// backlog no longer lines up. The list renders newest first (row 0 is the
  /// newest message), so a chronological index [i] maps to `length - 1 - i`.
  int? _renderAnchorIndex(List<UiMessage> messages, int count) {
    final forward = _anchorIndex(messages, count);
    if (forward == null) return null;
    return messages.length - 1 - forward;
  }

  void _scrollToAnchor(List<UiMessage> messages, int count) {
    final render = _renderAnchorIndex(messages, count);
    if (render == null) {
      _finishAnchoring();
      _scrollToLatest();
      return;
    }
    // The list is still to be built on the first reload, so the seek waits for
    // the frame that lays it out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_seekAnchor(render / messages.length, 0));
      }
    });
  }

  /// Offsets tried, as fractions of the scroll range, when looking for the
  /// anchor row. A lazily built [ListView] only lays out rows near the
  /// viewport, so [Scrollable.ensureVisible] cannot align a row it never
  /// built: bring it into the cache first. The estimate is the row's share of
  /// the list, and the fan out walks both ways from it because the row heights
  /// above the estimate need not match the ones below it.
  static const List<double> _anchorSearch = [0, -0.12, 0.12, -0.25, 0.25];

  Future<void> _seekAnchor(double fraction, int attempt) async {
    if (!mounted || !_scroll.hasClients) {
      _finishAnchoring();
      return;
    }
    final position = _scroll.position;
    final offset = (position.maxScrollExtent *
            (fraction + _anchorSearch[attempt]))
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    _scroll.jumpTo(offset);
    // Await a frame boundary rather than posting a callback from inside one:
    // a callback added during the post-frame phase of a frame still runs in
    // that same frame, which would look for the anchor before the list has
    // laid out the rows the jump scrolled to.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (!_scroll.hasClients) {
      _finishAnchoring();
      return;
    }
    final context = _anchorKey.currentContext;
    if (context != null && context.mounted) {
      // Rest the backlog at the top of the viewport: the messages left to
      // read are the ones below it, in order. A reversed list shows the
      // trailing edge on top, so the anchor aligns to 1.0.
      unawaited(Scrollable.ensureVisible(context, alignment: 1));
      _finishAnchoring();
      return;
    }
    if (attempt + 1 < _anchorSearch.length) {
      await _seekAnchor(fraction, attempt + 1);
      return;
    }
    // Never located the row, which means the backlog does not line up with
    // what is on screen. Showing the newest messages beats a wrong guess.
    _finishAnchoring();
    _scrollToLatest();
  }

  void _finishAnchoring() {
    if (!_anchorPending) return;
    _anchorPending = false;
    final follow = _followPending;
    _followPending = false;
    setState(() {});
    if (follow) _scrollToLatest();
  }

  /// True while the newest message is within [_followThreshold] of the edge,
  /// which is the resting position of someone reading the live tail. The list
  /// is reversed: the newest message is row 0 at the bottom, i.e. offset 0.
  bool get _isNearBottom {
    if (!_scroll.hasClients) return true;
    return _scroll.position.pixels <= _followThreshold;
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(0);
    });
  }

  Future<void> _send() async {
    if (!_canSend || _isBlocked) return;
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    final target = _replyingTo;
    final quote = target == null
        ? null
        : QuoteRef(
            refId: target.corrId.isNotEmpty ? target.corrId : target.id,
            authorX: _authorKey(target),
            preview: _quotePreview(target),
          );
    // Size the container the send will actually put on the wire, not just the
    // typed text: the header and the quote preview are part of the plaintext
    // the processor caps at [maxPlaintextBytes].
    if (utf8.encode(
          _composed(
            conversationId: widget.conversationId,
            isGroup: _isGroup,
            text: text,
            quote: quote,
          ),
        ).length >
        maxPlaintextBytes) {
      _warnSend('Message exceeds the 4 KB limit');
      return;
    }
    _composer.clear();
    var sent = false;
    try {
      sent = await widget.messenger.sendToConversation(
        conversationId: widget.conversationId,
        text: text,
        quote: quote,
      );
    } catch (_) {
      _warnSend('Message could not be sent', restore: text);
      return;
    }
    if (!sent) {
      _warnSend('Message could not be sent', restore: text);
      return;
    }
    if (!mounted) return;
    await widget.messenger.clearDraft(widget.conversationId);
    setState(() => _replyingTo = null);
    // An outgoing message is always followed to: the user just wrote it.
    await _reload(follow: true);
  }

  /// The one-line snippet a reply to [target] carries. A media bubble has no
  /// text, so it is named instead: a reply to a photo says "Photo".
  String _quotePreview(UiMessage target) {
    final media = target.media;
    if (media != null) {
      return switch (media.kind) {
        MediaKind.voice => SotyL10n.tr(context, 'Voice message'),
        MediaKind.video => SotyL10n.tr(context, 'Video'),
        MediaKind.photo => SotyL10n.tr(context, 'Photo'),
        MediaKind.file => SotyL10n.tr(context, 'File'),
      };
    }
    return _previewOf(target.body);
  }

  /// Starts a voice note. The microphone button is held, so the recording
  /// follows the finger: a release that arrives while the recorder is still
  /// warming up cancels the take instead of leaving it running.
  Future<void> _startRecording() async {
    if (_recording) return;
    _micPressed = true;
    final recorder = _media.recorder;
    final allowed = await recorder.ensurePermission();
    if (!allowed) {
      _micPressed = false;
      _warnSend('Microphone permission is required');
      return;
    }
    final started = await recorder.start();
    if (!started) {
      _micPressed = false;
      _warnSend('Recording failed');
      return;
    }
    if (!_micPressed) {
      await recorder.cancel();
      return;
    }
    _recordWatch
      ..reset()
      ..start();
    _recordElapsedMs = 0;
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(_recordTick, (_) => _tickRecording());
    if (!mounted) return;
    setState(() => _recording = true);
  }

  /// The microphone button was released: the take is sent.
  Future<void> _releaseRecording() async {
    _micPressed = false;
    if (!_recording) return;
    await _finishRecording(send: true);
  }

  /// Stops the recording and, when [send] is set, ships the take.
  Future<void> _finishRecording({required bool send}) async {
    if (!_recording) return;
    _recording = false;
    _recordTimer?.cancel();
    _recordTimer = null;
    _recordWatch.stop();
    final elapsed = _recordWatch.elapsedMilliseconds;
    if (mounted) setState(() {});
    final recorder = _media.recorder;
    if (!send) {
      await recorder.cancel();
      return;
    }
    final bytes = await recorder.stop();
    if (bytes == null) {
      _warnSend('Recording failed');
      return;
    }
    if (elapsed < minVoiceMs) {
      _warnSend('Voice message is too short');
      return;
    }
    await _sendChunkedMedia(
      kind: MediaKind.voice,
      mime: 'audio/mp4',
      bytes: bytes,
      byteCount: bytes.length,
      durationMs: elapsed,
      label: 'Voice message',
    );
  }

  /// Refreshes the elapsed time. Recording has no duration cap: the take is
  /// sent as slices, so its length is limited only by free space.
  void _tickRecording() {
    if (!_recording || !mounted) return;
    setState(() => _recordElapsedMs = _recordWatch.elapsedMilliseconds);
  }

  /// Banner for a chunked send: the slice count and a cancel button.
  Widget _transferBanner() {
    final total = _transferTotal;
    final value = total == 0 ? null : _transferSent / total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_transferLabel — $_transferSent/$total',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: value),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: SotyL10n.tr(context, 'Cancel transfer'),
            onPressed: () => _transferCancel?.cancel(),
          ),
        ],
      ),
    );
  }

  /// Picks a photo (gallery or camera) and sends it as a manifest plus
  /// slices, so a relay never stores it and the recipient can pull the parts.
  Future<void> _pickPhoto({bool camera = false}) async {
    PickedPhoto? photo;
    try {
      photo = await _media.picker.pick(camera: camera);
    } catch (_) {
      photo = null;
    }
    if (!mounted || photo == null) return;
    if (!isAcceptedPhotoMime(photo.mime)) {
      _warnSend('Unsupported photo format');
      return;
    }
    if (photo.bytes.length > maxMediaBlobBytes) {
      _warnSend(
        'Photo is too large (max {kb} KB)',
        args: {'kb': '${maxMediaBlobBytes ~/ 1024}'},
      );
      return;
    }
    await _sendChunkedMedia(
      kind: MediaKind.photo,
      mime: photo.mime,
      bytes: photo.bytes,
      byteCount: photo.bytes.length,
      durationMs: 0,
      label: 'Photo',
    );
  }

  /// Picks a video (gallery or camera) and sends it. Files up to the inline
  /// blob limit and beyond travel as slices; the transfer cap is enforced
  /// before anything is queued.
  Future<void> _pickVideo({bool camera = false}) async {
    final picker = _media.videoPicker;
    if (picker == null) return;
    PickedVideo? video;
    try {
      video = await picker.pick(camera: camera);
    } catch (_) {
      video = null;
    }
    if (!mounted || video == null) return;
    if (!isAcceptedVideoMime(video.mime)) {
      _warnSend('Unsupported video format');
      return;
    }
    if (video.size > maxTransferBytes) {
      _warnSend(
        'Video is too large (max {mb} MB)',
        args: {'mb': '${maxTransferBytes ~/ (1024 * 1024)}'},
      );
      return;
    }
    await _sendChunkedMedia(
      kind: MediaKind.video,
      mime: video.mime,
      bytes: video.hasFile ? null : video.bytes,
      path: video.hasFile ? video.path : null,
      byteCount: video.size,
      durationMs: 0,
      label: 'Video',
    );
  }

  /// Picks an arbitrary file and sends it as slices. The recipient only ever
  /// saves it; nothing in the app opens or executes it.
  Future<void> _pickFile() async {
    final picker = _media.filePicker;
    if (picker == null) return;
    PickedFile? file;
    try {
      file = await picker.pick();
    } catch (_) {
      file = null;
    }
    if (!mounted || file == null) return;
    if (file.size == 0 || file.size > maxTransferBytes) {
      _warnSend(
        'File is too large (max {mb} MB)',
        args: {'mb': '${maxTransferBytes ~/ (1024 * 1024)}'},
      );
      return;
    }
    await _sendChunkedMedia(
      kind: MediaKind.file,
      mime: file.mime,
      bytes: file.hasFile ? null : file.bytes,
      path: file.hasFile ? file.path : null,
      byteCount: file.size,
      durationMs: 0,
      label: 'File',
    );
  }

  /// The attach sheet: gallery photo/video, an arbitrary file, or the camera.
  Future<void> _openAttachSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: Text(SotyL10n.tr(ctx, 'Photo')),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(SotyL10n.tr(ctx, 'Video')),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(SotyL10n.tr(ctx, 'File')),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(SotyL10n.tr(ctx, 'Take photo')),
              onTap: () => Navigator.pop(ctx, 'camera_photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(SotyL10n.tr(ctx, 'Record video')),
              onTap: () => Navigator.pop(ctx, 'camera_video'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'photo':
        await _pickPhoto();
      case 'video':
        await _pickVideo();
      case 'file':
        await _pickFile();
      case 'camera_photo':
        await _pickPhoto(camera: true);
      case 'camera_video':
        await _pickVideo(camera: true);
    }
  }

  /// Sends a file as a manifest plus slices. A file up to [senderPushBytes]
  /// is pushed with a progress banner; a larger one only announces itself and
  /// the recipient pulls the slices, so the sender never uploads the file.
  Future<void> _sendChunkedMedia({
    required MediaKind kind,
    required String mime,
    Uint8List? bytes,
    String? path,
    required int byteCount,
    required int durationMs,
    required String label,
  }) async {
    final pushSlices = byteCount <= senderPushBytes;
    final cancel = TransferCancel();
    if (pushSlices) {
      setState(() {
        _transferCancel = cancel;
        _transferSent = 0;
        _transferTotal = 0;
        _transferLabel = SotyL10n.tr(context, label);
      });
    }
    try {
      await widget.messenger.sendFileToConversation(
        conversationId: widget.conversationId,
        kind: kind,
        mime: mime,
        bytes: bytes,
        path: path,
        durationMs: durationMs,
        cancel: pushSlices ? cancel : null,
        onProgress: pushSlices
            ? (sent, total) {
                if (!mounted) return;
                setState(() {
                  _transferSent = sent;
                  _transferTotal = total;
                });
              }
            : null,
      );
    } on TransferCancelled {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SotyL10n.tr(context, 'Transfer cancelled'))),
        );
      }
      return;
    } catch (_) {
      _warnSend('Message could not be sent');
      return;
    } finally {
      if (pushSlices && mounted) {
        setState(() => _transferCancel = null);
      }
    }
    if (!mounted) return;
    setState(() => _replyingTo = null);
    await _reload(follow: true);
  }

  /// The microphone button. It is held, not tapped: the recording starts on
  /// the press and stops on the release.
  Widget _recordButton() {
    final theme = Theme.of(context);
    final active = _recording;
    return Tooltip(
      message: SotyL10n.tr(context, 'Voice message'),
      child: Listener(
        onPointerDown: (_) => unawaited(_startRecording()),
        onPointerUp: (_) => unawaited(_releaseRecording()),
        onPointerCancel: (_) => unawaited(_finishRecording(send: false)),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? theme.colorScheme.error
                : theme.colorScheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            active ? Icons.stop : Icons.mic,
            size: 20,
            color: active
                ? theme.colorScheme.onError
                : theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }

  /// The recording banner: the countdown of the seconds left before the
  /// take is cut off, and the button that throws it away.
  Widget _recordingBanner() {
    final theme = Theme.of(context);
    final elapsed = Duration(milliseconds: _recordElapsedMs);
    final clock = '${elapsed.inMinutes}:'
        '${elapsed.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          children: [
            Icon(
              Icons.mic,
              size: 18,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                SotyL10n.tr(
                  context,
                  'Recording… {time}',
                  {'time': clock},
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: SotyL10n.tr(context, 'Cancel'),
              onPressed: () => unawaited(_finishRecording(send: false)),
            ),
          ],
        ),
      ),
    );
  }

  /// The container a send to [conversationId] will compose, so the composer
  /// and the forward picker can size check it before anything is cleared. The
  /// group correlation id is a fixed-width hex string, so a placeholder gives
  /// the exact byte count.
  String _composed({
    required String conversationId,
    required bool isGroup,
    required String text,
    QuoteRef? quote,
  }) =>
      isGroup
          ? MessagePayload.composeGroupMessage(
              conversationId: conversationId,
              corrId: '0' * 64,
              senderX: widget.messenger.myXPubKey,
              text: text,
              quote: quote,
            )
          : MessagePayload.composeDirect(
              senderX: widget.messenger.myXPubKey,
              text: text,
              quote: quote,
            );

  /// The one-line quote snippet a reply carries: the first line of the
  /// original body, clamped to the preview limit.
  static String _previewOf(String body) {
    final line = body.split('\n').first;
    return line.runes.length <= maxQuotePreviewChars
        ? line
        : String.fromCharCodes(line.runes.take(maxQuotePreviewChars));
  }

  /// Inserts [emoji] at the composer caret (replacing any selection) and
  /// remembers it as recently used so it leads the panel's first tab.
  Future<void> _insertEmoji(String emoji) async {
    final value = _composer.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    _composer.value = TextEditingValue(
      text: text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    await widget.prefs.noteEmoji(emoji);
    if (mounted) setState(() {});
  }

  /// The picker shown above the composer: a tab strip (recents + categories)
  /// over a grid that inserts on tap.
  Widget _emojiPanel() {
    final recents = widget.prefs.emojiRecents;
    final tab = _emojiTab.clamp(0, emojiCategories.length);
    final items = tab == 0 ? recents : emojiCategories[tab - 1].emoji;
    return SizedBox(
      height: 232,
      child: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: emojiCategories.length + 1,
              itemBuilder: (ctx, i) => IconButton(
                icon: Icon(
                  i == 0 ? Icons.history : emojiCategories[i - 1].icon,
                ),
                tooltip: SotyL10n.tr(
                  context,
                  i == 0 ? 'Recent' : emojiCategories[i - 1].label,
                ),
                isSelected: i == tab,
                onPressed: () => setState(() => _emojiTab = i),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(SotyL10n.tr(context, 'No recent emoji')),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(6),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                        ),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) => InkWell(
                      onTap: () => _insertEmoji(items[i]),
                      child: Center(
                        child: Text(
                          items[i],
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// The quote the composer is answering: the original's first line plus a
  /// dismiss button. Dismissing keeps the draft.
  Widget _replyBanner() {
    final target = _replyingTo!;
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    SotyL10n.tr(context, 'Reply'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    _previewOf(target.body),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: SotyL10n.tr(context, 'Cancel'),
              onPressed: () => setState(() => _replyingTo = null),
            ),
          ],
        ),
      ),
    );
  }

  /// The message action menu, offered on a long press on any bubble. Reply is
  /// withheld when there is nothing to quote by: an undecryptable bubble, a
  /// legacy group container with no correlation id, or a plain-text fallback
  /// whose container carried no author key.
  Widget _bubble(UiMessage message, Widget child) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (details) =>
            _bubbleMenu(message, details.globalPosition),
        child: child,
      );

  bool _replyable(UiMessage message) => message.body != encryptedPlaceholder &&
      isHexOfLength(_authorKey(message), 32) &&
      (!_isGroup || message.corrId.isNotEmpty);

  /// The X25519 address a reply attributes the quoted message to. It comes
  /// from the verified signer binding the controller resolved, never from the
  /// container's own claim. For a 1:1 chat every message is by definition
  /// that peer's, so the conversation's key is a sound last resort.
  String _authorKey(UiMessage message) {
    if (isHexOfLength(message.senderX, 32)) return message.senderX;
    if (_isGroup) return '';
    final bound = widget.messenger.peerByEdPubKey(widget.conversationId);
    return bound?.pubKey ?? widget.conversationId;
  }

  Future<void> _bubbleMenu(UiMessage message, Offset globalPos) async {
    final isMedia = message.media != null;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        globalPos.dx,
        globalPos.dy,
      ),
      items: [
        if (_replyable(message))
          PopupMenuItem(
            value: 'reply',
            child: Text(SotyL10n.tr(context, 'Reply')),
          ),
        // A media bubble carries no prose: there is nothing to copy, share
        // or forward as text.
        if (!isMedia) ...[
          PopupMenuItem(
            value: 'forward',
            child: Text(SotyL10n.tr(context, 'Forward')),
          ),
          PopupMenuItem(
            value: 'copy',
            child: Text(SotyL10n.tr(context, 'Copy')),
          ),
          PopupMenuItem(
            value: 'share',
            child: Text(SotyL10n.tr(context, 'Share')),
          ),
        ],
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'reply':
        setState(() => _replyingTo = message);
        return;
      case 'forward':
        await _forward(message);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.body));
      case 'share':
        await _share(message.body);
    }
  }

  /// Shares [text] through the system share sheet; desktop has no channel, so
  /// it falls back to the clipboard and says so.
  Future<void> _share(String text) async {
    if (await ShareService.shareText(text)) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(SotyL10n.tr(context, 'Copied'))),
    );
  }

  /// Picks a conversation and re-sends [message]'s text there, prefixed with
  /// its author so a forward stays attributable. Forwarding is plain text on
  /// purpose: it carries no quote, so the recipient never learns a key the
  /// sender did not already share with them.
  Future<void> _forward(UiMessage message) async {
    final candidates = widget.messenger.conversationList
        .where((c) => c.id != widget.conversationId)
        .toList(growable: false);
    if (candidates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SotyL10n.tr(context, 'No conversations yet.'))),
      );
      return;
    }
    final target = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                SotyL10n.tr(context, 'Forward to'),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final c in candidates)
              ListTile(
                title: Text(
                  widget.messenger.chatTitle(c.id),
                ),
                subtitle: c.isGroup
                    ? Text(SotyL10n.tr(ctx, 'Group'))
                    : null,
                onTap: () => Navigator.of(ctx).pop(c.id),
              ),
          ],
        ),
      ),
    );
    if (target == null || !mounted) return;
    final media = message.media;
    if (media != null) {
      // A media bubble is forwarded as the same encrypted attachment, not as
      // a text caption: the recipient gets a playable/visible bubble. A file
      // over the inline cap is re-sent as slices.
      try {
        if (media.kind == MediaKind.voice) {
          await widget.messenger.sendMediaToConversation(
            conversationId: target,
            kind: media.kind,
            mime: media.mime,
            dataBase64: media.dataBase64,
            durationMs: media.durationMs,
          );
        } else {
          final stored = await widget.messenger.mediaBlob(media.blobId);
          final file = await stored?.file();
          final bytes = file == null && media.dataBase64.isNotEmpty
              ? base64Decode(media.dataBase64)
              : null;
          if (file == null && bytes == null) {
            if (mounted) _warnSend('Message could not be sent');
            return;
          }
          await widget.messenger.sendFileToConversation(
            conversationId: target,
            kind: media.kind,
            mime: media.mime,
            bytes: bytes,
            path: file?.path,
            durationMs: media.durationMs,
          );
        }
      } catch (_) {
        if (mounted) _warnSend('Message could not be sent');
      }
      return;
    }
    final author = widget.messenger.chatTitle(_authorKey(message));
    final forwarded = '↪ $author\n${message.body}';
    final targetIsGroup =
        candidates.firstWhere((c) => c.id == target).isGroup;
    if (utf8.encode(
          _composed(
            conversationId: target,
            isGroup: targetIsGroup,
            text: forwarded,
          ),
        ).length >
        maxPlaintextBytes) {
      _warnSend('Message exceeds the 4 KB limit');
      return;
    }
    var ok = false;
    try {
      ok = await widget.messenger.sendToConversation(
        conversationId: target,
        text: forwarded,
      );
    } catch (_) {
      _warnSend('Message could not be sent');
      return;
    }
    if (!ok) _warnSend('Message could not be sent');
  }

  /// Puts [restore] back into the composer and tells the user why the send
  /// did not go out, so a rejected message is never silently lost.
  void _warnSend(
    String message, {
    String? restore,
    Map<String, Object> args = const {},
  }) {
    if (!mounted) return;
    if (restore != null) {
      _composer.value = TextEditingValue(
        text: restore,
        selection: TextSelection.collapsed(offset: restore.length),
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(SotyL10n.tr(context, message, args))),
    );
  }

  bool get _canSend => widget.messenger.canSendTo(widget.conversationId);

  bool get _isBlocked =>
      widget.messenger.isPeerBlocked(widget.conversationId);

  /// Handles a hardware Enter in the composer: sends while the send-on-enter
  /// preference is on, and still inserts a new line on Shift+Enter.
  KeyEventResult _onComposerKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isEnter = key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (!isEnter || HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    _send();
    return KeyEventResult.handled;
  }

  /// Composer import flow for unattributable chats: scan the contact's QR,
  /// paste their signed invite JSON, or type the keys by hand — the same
  /// three channels as the identity screen, inlined so the reply barrier is
  /// removable in place.
  Future<void> _importContact() async {
    final channel = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(SotyL10n.tr(ctx, 'Import contact')),
        children: [
          _importOption(ctx, Icons.qr_code_scanner, 'Scan QR code', 'scan'),
          _importOption(ctx, Icons.content_paste, 'Paste invite JSON', 'json'),
          _importOption(ctx, Icons.edit_outlined, 'Enter manually', 'manual'),
        ],
      ),
    );
    if (!mounted) return;
    var imported = false;
    switch (channel) {
      case 'scan':
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => ScanQrScreen(messenger: widget.messenger),
          ),
        );
        imported = ok ?? false;
      case 'json':
        imported = await _importByJson() ?? false;
      case 'manual':
        imported = await _importManually() ?? false;
    }
    if (!mounted) return;
    if (imported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SotyL10n.tr(context, 'Peer imported'))),
      );
      await _reload();
    }
  }

  Widget _importOption(
    BuildContext ctx,
    IconData icon,
    String label,
    String value,
  ) =>
      SimpleDialogOption(
        onPressed: () => Navigator.of(ctx).pop(value),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Text(SotyL10n.tr(ctx, label)),
          ],
        ),
      );

  Future<bool?> _importByJson() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(SotyL10n.tr(ctx, 'Import invite')),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 3,
          decoration: InputDecoration(
            hintText: SotyL10n.tr(ctx, 'Paste the invite JSON here'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(SotyL10n.tr(ctx, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(SotyL10n.tr(ctx, 'Import')),
          ),
        ],
      ),
    );
    if (!mounted) return null;
    if (ok != true) return null;
    return widget.messenger.importInvite(controller.text.trim());
  }

  Future<bool?> _importManually() async {
    final xKeyController = TextEditingController();
    final nameController = TextEditingController();
    final peerIdController = TextEditingController();
    final addrController = TextEditingController();
    final peer = await showDialog<DtmPeer>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(SotyL10n.tr(ctx, 'Add peer')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: xKeyController,
                decoration: InputDecoration(
                  labelText: SotyL10n.tr(
                    ctx,
                    'Peer X25519 public key (hex)',
                  ),
                ),
              ),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: SotyL10n.tr(ctx, 'Name (optional)'),
                ),
                maxLength: maxDisplayNameLength,
              ),
              TextField(
                controller: peerIdController,
                decoration: InputDecoration(
                  labelText: SotyL10n.tr(ctx, 'libp2p peer id (optional)'),
                ),
              ),
              TextField(
                controller: addrController,
                decoration: InputDecoration(
                  labelText: SotyL10n.tr(ctx, 'Multiaddr (optional)'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(SotyL10n.tr(ctx, 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final key = xKeyController.text.trim();
              if (!isHexOfLength(key, 32)) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      SotyL10n.tr(
                        ctx,
                        'Public key must be 64 hex characters',
                      ),
                    ),
                  ),
                );
                return;
              }
              Navigator.of(ctx).pop(
                DtmPeer(
                  pubKey: key,
                  displayName: nameController.text.trim(),
                  peerId: peerIdController.text.trim().isEmpty
                      ? null
                      : peerIdController.text.trim(),
                  addrs: addrController.text.trim().isEmpty
                      ? const <String>[]
                      : [addrController.text.trim()],
                  lastSeen: DateTime.now(),
                ),
              );
            },
            child: Text(SotyL10n.tr(ctx, 'Start')),
          ),
        ],
      ),
    );
    if (peer == null) return false;
    return widget.messenger.importPeer(peer);
  }

  String get _peerTitle => widget.messenger.chatTitle(widget.conversationId);

  bool get _isGroup => widget.messenger.isGroup(widget.conversationId);

  DtmPeer? get _peer =>
      _isGroup ? null : widget.messenger.peers[widget.conversationId];

  PeerPresence get _presence => presenceOf(_peer);

  static final TextStyle _statusStyle =
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w500);

  Future<void> _openGroupInfo() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupInfoScreen(
          messenger: widget.messenger,
          conversationId: widget.conversationId,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openSecurity() async {
    final peer = _peer;
    if (peer == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PeerSecurityScreen(
          messenger: widget.messenger,
          peerPubKey: peer.pubKey,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _rename() async {
    final name = await showPeerNameDialog(
      context,
      title: SotyL10n.tr(context, 'Rename chat'),
      initial: _peerTitle,
    );
    if (name != null && mounted) {
      await widget.messenger.renameConversation(widget.conversationId, name);
    }
  }

  Widget _systemLine(UiMessage message) {
    final theme = Theme.of(context);
    String name(String key) {
      if (key.isEmpty) return '';
      if (key == widget.messenger.myXPubKey) {
        return SotyL10n.tr(context, 'You');
      }
      final label = widget.messenger.senderNameFor(key);
      return label.isEmpty ? key : label;
    }

    final actor = name(message.systemActor);
    final target = name(message.systemTarget);
    final text = switch (message.systemAction) {
      'a' => SotyL10n.tr(
          context,
          '{actor} added {name}',
          {'actor': actor, 'name': target},
        ),
      'r' => SotyL10n.tr(
          context,
          '{actor} removed {name}',
          {'actor': actor, 'name': target},
        ),
      'p' => SotyL10n.tr(
          context,
          '{actor} made {name} an admin',
          {'actor': actor, 'name': target},
        ),
      'd' => SotyL10n.tr(
          context,
          '{actor} removed admin rights from {name}',
          {'actor': actor, 'name': target},
        ),
      _ => '',
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _blockedBanner() {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.block,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                SotyL10n.tr(
                  context,
                  'You blocked this contact. Unblock it in the safety '
                  'screen.',
                ),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unsentBanner() {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              Icons.schedule_send_outlined,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    SotyL10n.tr(
                      context,
                      'Not delivered yet ({n})',
                      {'n': '$_pendingOutgoing'},
                    ),
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    SotyL10n.tr(
                      context,
                      'Message not delivered yet — Soty will retry when the '
                      'peer is reachable.',
                    ),
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _retryPending,
              child: Text(SotyL10n.tr(context, 'Retry')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retryPending() async {
    await widget.messenger.retryPending();
    if (!mounted) return;
    final pending = (await widget.messenger.pendingOutgoing(
      widget.conversationId,
    ))
        .length;
    if (!mounted) return;
    setState(() => _pendingOutgoing = pending);
  }

  Widget _securityBanner() {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: InkWell(
        onTap: _openSecurity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  SotyL10n.tr(context, 'Security code changed'),
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openSecurity,
                child: Text(SotyL10n.tr(context, 'Safety number')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _anchorItem = _anchorPending
        ? _renderAnchorIndex(_messages, _unreadAtEntry)
        : null;
    final unavailableText = _isGroup
        ? SotyL10n.tr(
            context,
            'You are no longer a member of this group.',
          )
        : SotyL10n.tr(
            context,
            'Unknown contact — import it first to reply.',
          );
    // At large accessibility text sizes the presence label would push the
    // app-bar actions past the screen width; the icon alone still conveys it.
    final showPresenceLabel =
        MediaQuery.textScalerOf(context).scale(_statusStyle.fontSize ?? 12) <=
            18;
    return Scaffold(
      appBar: AppBar(
        title: Text(_peerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: SotyL10n.tr(context, 'Search'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SearchScreen(
                    messenger: widget.messenger,
                    prefs: widget.prefs,
                    onSotyLink: widget.onSotyLink,
                    conversationId: widget.conversationId,
                  ),
                ),
              );
            },
          ),
          if (_isGroup)
            IconButton(
              icon: const Icon(Icons.group_outlined),
              tooltip: SotyL10n.tr(context, 'Group info'),
              onPressed: _openGroupInfo,
            ),
          if (!_isGroup)
            IconButton(
              icon: const Icon(Icons.shield_outlined),
              tooltip: SotyL10n.tr(context, 'Safety number'),
              onPressed: _openSecurity,
            ),
          IconButton(
            icon: const Icon(Icons.drive_file_rename_outline),
            tooltip: SotyL10n.tr(context, 'Rename chat'),
            onPressed: _rename,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isGroup)
                  Icon(
                    _presence == PeerPresence.online
                        ? Icons.wifi
                        : Icons.wifi_off,
                    size: 18,
                    color: switch (_presence) {
                      PeerPresence.online => Colors.green,
                      PeerPresence.recent => Colors.orange,
                      PeerPresence.offline => Colors.grey,
                    },
                  ),
                if (!_isGroup && showPresenceLabel) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      presenceLabel(context, _peer),
                      style: _statusStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isGroup && (_peer?.keyChanged ?? false)) _securityBanner(),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? Center(
                        child: Text(SotyL10n.tr(context, 'No messages yet.')),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          if (i == _messages.length - 1 &&
                              _messages.length >= _pageLimit) {
                            // Reaching the oldest row loads the next page.
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) unawaited(_loadOlder());
                            });
                          }
                          final message = _messages[_messages.length - 1 - i];
                          if (message.isSystem) {
                            final line = _systemLine(message);
                            return i == _anchorItem
                                ? KeyedSubtree(key: _anchorKey, child: line)
                                : line;
                          }
                          final bubble = _MessageBubble(
                            message: message,
                            senderLabel: _isGroup && !message.outgoing
                                ? widget.messenger
                                    .senderNameFor(_authorKey(message))
                                : null,
                            onSotyLink: widget.onSotyLink,
                            onDownload: widget.messenger.startTransferDownload,
                            newPlayer: _media.newPlayer,
                          );
                          return i == _anchorItem
                              ? KeyedSubtree(
                                  key: _anchorKey,
                                  child: _bubble(message, bubble),
                                )
                              : _bubble(message, bubble);
                        },
                      ),
                // While the unread backlog is being located, cover the list so
                // the user never sees it flash past the target position. The
                // first visible frame is the anchored one.
                if (_anchorPending)
                  ColoredBox(
                    key: const ValueKey('anchorOverlay'),
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: const SizedBox.expand(),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_transferCancel != null) _transferBanner(),
          if (_canSend && _recording) _recordingBanner(),
          if (_canSend && _replyingTo != null) _replyBanner(),
          if (_pendingOutgoing > 0) _unsentBanner(),
          if (_isBlocked) _blockedBanner(),
          if (_canSend && _emojiOpen) _emojiPanel(),
          SafeArea(
            top: false,
            child: _canSend
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Focus(
                            onKeyEvent: !widget.prefs.sendOnEnter
                                ? null
                                : _onComposerKey,
                            child: TextField(
                              controller: _composer,
                              enabled: !_isBlocked,
                              minLines: 1,
                              maxLines: widget.prefs.sendOnEnter ? 1 : 4,
                              maxLength: maxPlaintextBytes,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: widget.prefs.sendOnEnter
                                  ? TextInputAction.send
                                  : TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: SotyL10n.tr(
                                  context,
                                  'Text message',
                                ),
                                border: const OutlineInputBorder(),
                                counterText: '',
                              ),
                              onSubmitted: widget.prefs.sendOnEnter
                                  ? (_) => _send()
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.emoji_emotions_outlined),
                          tooltip: SotyL10n.tr(context, 'Emoji'),
                          isSelected: _emojiOpen,
                          onPressed: _toggleEmoji,
                        ),
                        if (!_isBlocked && !_hasComposerText) ...[
                          IconButton(
                            icon: const Icon(Icons.attach_file),
                            tooltip: SotyL10n.tr(context, 'Attach'),
                            onPressed: () => unawaited(_openAttachSheet()),
                          ),
                          _recordButton(),
                        ],
                        IconButton.filled(
                          icon: const Icon(Icons.send),
                          tooltip: SotyL10n.tr(context, 'Send'),
                          onPressed: _isBlocked ? null : _send,
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          unavailableText,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _importContact,
                          icon: const Icon(Icons.person_add_alt),
                          label: Text(
                            SotyL10n.tr(context, 'Import contact'),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final UiMessage message;

  /// Name of the author shown above an inbound group message (`null` in a 1:1
  /// chat and for our own bubbles, where the alignment already says who wrote).
  final String? senderLabel;

  /// Handles a tapped `soty://` link in the body, as carried by `ChatScreen`.
  final Future<void> Function(String route)? onSotyLink;

  /// Starts an explicit download of a large transfer the user tapped.
  final Future<void> Function(String transferId)? onDownload;

  /// Builds the player a voice note bubble owns.
  final VoicePlayer Function() newPlayer;

  const _MessageBubble({
    required this.message,
    this.senderLabel,
    this.onSotyLink,
    this.onDownload,
    required this.newPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment = message.outgoing
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final color = message.outgoing
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final label = senderLabel;
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (label != null && label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (message.quote != null)
              _QuotePlaque(quote: message.quote!),
            if (message.media != null)
              MediaBubble(media: message.media!, newPlayer: newPlayer)
            else if (message.transfer != null)
              _TransferBubble(
                transfer: message.transfer!,
                onDownload: onDownload,
              )
            else
              LinkifiedText(
                message.body,
                style: const TextStyle(fontSize: 15),
                onSotyLink: onSotyLink,
              ),
            if (message.outgoing && message.status != null)
              _StatusTick(status: message.status!),
          ],
        ),
      ),
    );
  }
}

/// The quoted excerpt a reply carries: a compact block above the reply body
/// showing the original's first line. The preview travels in the payload, so
/// it renders even when the original was pruned or never seen.
class _QuotePlaque extends StatelessWidget {
  final QuoteRef quote;

  const _QuotePlaque({required this.quote});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = quote.preview.isEmpty
        ? SotyL10n.tr(context, 'No messages yet.')
        : quote.preview;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            SotyL10n.tr(context, 'Reply'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// The delivery mark under one of our own bubbles: a clock while it waits for
/// a transport, one check once handed over, two once delivered, and two in the
/// accent color once read.
class _StatusTick extends StatelessWidget {
  final MessageStatus status;

  const _StatusTick({required this.status});

  static const Map<MessageStatus, IconData> _icons = {
    MessageStatus.queued: Icons.schedule,
    MessageStatus.sent: Icons.check,
    MessageStatus.delivered: Icons.done_all,
    MessageStatus.read: Icons.done_all,
  };

  static String _label(MessageStatus status) => switch (status) {
        MessageStatus.queued => 'Sending',
        MessageStatus.sent => 'Sent',
        MessageStatus.delivered => 'Delivered',
        MessageStatus.read => 'Read',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = status == MessageStatus.read
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Tooltip(
        message: SotyL10n.tr(context, _label(status)),
        child: Icon(_icons[status], size: 14, color: color),
      ),
    );
  }
}


/// An inbound chunked file that is still assembling: the kind, the progress
/// bar and the bytes received so far. It becomes a normal media bubble the
/// moment the file digest checks out.
class _TransferBubble extends StatelessWidget {
  final TransferInfo transfer;
  final Future<void> Function(String transferId)? onDownload;

  const _TransferBubble({required this.transfer, this.onDownload});

  @override
  Widget build(BuildContext context) {
    final label = switch (transfer.kind) {
      MediaKind.voice => SotyL10n.tr(context, 'Voice message'),
      MediaKind.video => SotyL10n.tr(context, 'Video'),
      MediaKind.photo => SotyL10n.tr(context, 'Photo'),
      MediaKind.file => SotyL10n.tr(context, 'File'),
    };
    final totalKb = (transfer.byteCount / 1024).ceil();
    final receivedKb = (transfer.receivedBytes / 1024).floor();
    final waiting = transfer.receivedBytes == 0;
    final senderOffline = waiting && !transfer.senderOnline;
    final sizeMb = (transfer.byteCount / (1024 * 1024)).toStringAsFixed(1);
    final waitingText = transfer.isGroup
        ? SotyL10n.tr(
            context,
            'Waiting for a group member to share this file',
          )
        : SotyL10n.tr(
            context,
            'The sender is offline. The file will download when they return.',
          );
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                switch (transfer.kind) {
                  MediaKind.video => Icons.videocam_outlined,
                  MediaKind.voice => Icons.mic_none,
                  MediaKind.photo => Icons.image_outlined,
                  MediaKind.file => Icons.insert_drive_file_outlined,
                },
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  waiting
                      ? label
                      : '$label — ${SotyL10n.tr(context, 'Receiving')}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (transfer.canStart)
            FilledButton.icon(
              onPressed: onDownload == null
                  ? null
                  : () => unawaited(onDownload!(transfer.transferId)),
              icon: const Icon(Icons.download, size: 18),
              label: Text(
                '${SotyL10n.tr(context, 'Download')} · $sizeMb MB',
              ),
            )
          else ...[
            LinearProgressIndicator(
              value: waiting ? null : transfer.progress,
            ),
            const SizedBox(height: 6),
          ],
          if (!transfer.canStart && senderOffline)
            Text(
              waitingText,
              style: const TextStyle(fontSize: 11),
            )
          else if (!transfer.canStart && waiting)
            Text(
              SotyL10n.tr(context, 'Receiving'),
              style: const TextStyle(fontSize: 11),
            )
          else if (!transfer.canStart)
            Text(
              '${(transfer.progress * 100).floor()}% · '
              '$receivedKb / $totalKb KB',
              style: const TextStyle(fontSize: 11),
            ),
        ],
      ),
    );
  }
}
