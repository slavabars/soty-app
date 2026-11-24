import 'dart:convert' show base64Decode;
import 'dart:typed_data';

import '../core/crypto/hex.dart' show isHexOfLength;
import '../core/media/chunked_transfer.dart' show ChunkManifest, FileChunk;
import '../core/security_limits.dart'
    show
        maxGroupMembers,
        maxMediaBlobBytes,
        maxMediaMimeLength,
        maxQuotePreviewChars,
        maxReceiptIds,
        maxTransferBytes,
        maxTransferChunks,
        mediaAudioMimePrefixes,
        mediaImageMimeTypes,
        mediaVideoMimeTypes,
        transferChunkBytes;
import 'group_payload.dart';

enum ReceiptKind { delivered, read }

/// What a media container carries.
enum MediaKind { voice, photo, video, file }

/// Wire tags for [MediaKind]; an unknown tag makes the container plain text.
const String _voiceTag = 'voice';
const String _photoTag = 'photo';

/// Wire tag for [MediaKind.video]; unknown tags degrade to plain text.
const String _videoTag = 'video';

/// Wire tag for an arbitrary downloadable file (never played inline).
const String _fileTag = 'file';

/// A MIME type a `file` container accepts: a plain `type/subtype` token, no
/// control characters and no family restriction, because the whole point is
/// an arbitrary download that is never decoded by the app itself.
final RegExp _fileMime = RegExp(
  r'^[a-z0-9][a-z0-9!#$&^_.+-]{0,63}/[a-z0-9][a-z0-9!#$&^_.+-]{0,63}$',
  caseSensitive: false,
);

/// Quote preview carried with a reply: the id and author of the quoted
/// message plus a one-line snippet, so the quote renders even after the
/// original is pruned or was never seen.
class QuoteRef {
  final String refId;
  final String authorX;
  final String preview;

  const QuoteRef({
    required this.refId,
    required this.authorX,
    required this.preview,
  });
}

/// A decrypted plaintext classified by its shape. Everything a peer sends is
/// untrusted, so [MessagePayload.parse] is total: anything that does not match
/// a container strictly is ordinary [TextPayload] and is never dropped.
sealed class MessagePayload {
  const MessagePayload();

  /// Recognizes direct messages (`x1`/`x2` + sender/ref/quote X25519 keys),
  /// receipts (`d1`/`r1` + a bounded id list), the current group containers
  /// (`g2`/`g3`/`t1`) and the legacy ones (`g1`/`m1`). Unknown or malformed
  /// input is [TextPayload] with the original text, so a hostile sender can
  /// never make a message vanish.
  static MessagePayload parse(String raw) {
    final newline = raw.indexOf('\n');
    final header = newline == -1 ? raw : raw.substring(0, newline);
    final body = newline == -1 ? '' : raw.substring(newline + 1);

    if (header.startsWith('x1 ')) {
      final senderX = header.substring(3);
      if (isHexOfLength(senderX, 32)) {
        return DirectPayload(senderX: senderX, text: body);
      }
      return TextPayload(raw);
    }

    if (header.startsWith('x2 ')) {
      final parts = header.split(' ');
      if (parts.length == 4 &&
          isHexOfLength(parts[1], 32) &&
          isHexOfLength(parts[2], 32) &&
          isHexOfLength(parts[3], 32)) {
        final split = _splitQuote(parts[2], parts[3], body);
        if (split != null) {
          return DirectPayload(
            senderX: parts[1],
            text: split.$2,
            quote: split.$1,
          );
        }
        // A well-formed reply header whose preview line is missing: keep the
        // message, drop the unusable quote.
        return DirectPayload(senderX: parts[1], text: body);
      }
      return TextPayload(raw);
    }

    if (header == 'd1' || header == 'r1') {
      // A receipt is a control frame even when its id list is unusable: it must
      // never surface as a text bubble showing the raw `d1 …` protocol string.
      return ReceiptPayload(
        kind: header == 'd1' ? ReceiptKind.delivered : ReceiptKind.read,
        ids: _parseIds(body),
      );
    }

    if (header.startsWith('g2 ')) {
      final parts = header.split(' ');
      if (parts.length == 4 &&
          isHexOfLength(parts[1], 32) &&
          isHexOfLength(parts[2], 32) &&
          isHexOfLength(parts[3], 32)) {
        return GroupMessagePayload(
          conversationId: parts[1],
          corrId: parts[2],
          senderX: parts[3],
          kind: GroupContainerKind.message,
          value: body,
        );
      }
      return TextPayload(raw);
    }

    if (header.startsWith('t3 ')) {
      final parts = header.split(' ');
      if (parts.length == 5 &&
          isHexOfLength(parts[1], 32) &&
          isHexOfLength(parts[2], 32) &&
          (parts[4] == '-' || isHexOfLength(parts[4], 32))) {
        final action = parts[3];
        const actions = {'a', 'r', 'p', 'd', 'c'};
        if (actions.contains(action)) {
          final keys = body.isEmpty ? <String>[] : body.split(',');
          if (keys.length <= maxGroupMembers &&
              keys.every((key) => isHexOfLength(key, 32))) {
            return GroupMessagePayload(
              conversationId: parts[1],
              corrId: '',
              senderX: parts[2],
              kind: GroupContainerKind.roster,
              value: parts[4] == '-' ? '' : parts[4],
              rosterAction: action,
              rosterKeys: keys,
            );
          }
        }
      }
      return TextPayload(raw);
    }

    if (header.startsWith('g3 ')) {
      final parts = header.split(' ');
      if (parts.length == 6 &&
          isHexOfLength(parts[1], 32) &&
          isHexOfLength(parts[2], 32) &&
          isHexOfLength(parts[3], 32) &&
          isHexOfLength(parts[4], 32) &&
          isHexOfLength(parts[5], 32)) {
        final split = _splitQuote(parts[4], parts[5], body);
        if (split != null) {
          return GroupMessagePayload(
            conversationId: parts[1],
            corrId: parts[2],
            senderX: parts[3],
            kind: GroupContainerKind.message,
            value: split.$2,
            quote: split.$1,
          );
        }
        // Well-formed group reply header with no preview line: keep it in the
        // group as a plain member message rather than dropping it to a 1:1.
        return GroupMessagePayload(
          conversationId: parts[1],
          corrId: parts[2],
          senderX: parts[3],
          kind: GroupContainerKind.message,
          value: body,
        );
      }
      return TextPayload(raw);
    }

    if (header.startsWith('t1 ')) {
      final parts = header.split(' ');
      if (parts.length == 3 &&
          isHexOfLength(parts[1], 32) &&
          isHexOfLength(parts[2], 32)) {
        return GroupMessagePayload(
          conversationId: parts[1],
          corrId: '',
          senderX: parts[2],
          kind: GroupContainerKind.title,
          value: body,
        );
      }
      return TextPayload(raw);
    }

    if (header.startsWith('f1 ') || header.startsWith('f2 ')) {
      final manifest = _parseFileManifest(header, body);
      return manifest ?? const DroppedPayload();
    }

    if (header.startsWith('c1 ') || header.startsWith('c2 ')) {
      final chunk = _parseFileChunk(header, body);
      return chunk ?? const DroppedPayload();
    }

    if (header.startsWith('q1 ') || header.startsWith('q2 ')) {
      final request = _parseFileRequest(header);
      return request ?? const DroppedPayload();
    }

    if (header.startsWith('m1 ') || header.startsWith('m2 ')) {
      final media = _parseMedia(header, body);
      return media ?? const DroppedPayload();
    }

    final legacy = GroupPayload.tryParseGroup(raw);
    if (legacy != null) {
      return GroupMessagePayload(
        conversationId: legacy.conversationId,
        corrId: '',
        senderX: '',
        kind: legacy.kind,
        value: legacy.value,
      );
    }
    return TextPayload(raw);
  }

  static String composeDirect({
    required String senderX,
    required String text,
    QuoteRef? quote,
  }) {
    if (quote == null ||
        !isHexOfLength(quote.refId, 32) ||
        !isHexOfLength(quote.authorX, 32)) {
      return 'x1 $senderX\n$text';
    }
    final preview = _sanitizePreview(quote.preview);
    return 'x2 $senderX ${quote.refId} ${quote.authorX}\n$preview\n$text';
  }

  static String composeGroupMessage({
    required String conversationId,
    required String corrId,
    required String senderX,
    required String text,
    QuoteRef? quote,
  }) {
    if (quote == null ||
        !isHexOfLength(quote.refId, 32) ||
        !isHexOfLength(quote.authorX, 32)) {
      return 'g2 $conversationId $corrId $senderX\n$text';
    }
    final preview = _sanitizePreview(quote.preview);
    return 'g3 $conversationId $corrId $senderX ${quote.refId} '
        '${quote.authorX}\n$preview\n$text';
  }

  static String composeGroupTitle({
    required String conversationId,
    required String senderX,
    required String title,
  }) {
    return 't1 $conversationId $senderX\n$title';
  }

  /// Full-roster sync broadcast by an admin:
  /// `t3 <conv> <sender> <action> <target|->\n<key,key,...>`.
  ///
  /// Every change carries the whole roster, so a lost or out-of-order frame
  /// cannot leave two members with different member lists.
  static String composeGroupRoster({
    required String conversationId,
    required String senderX,
    required String action,
    required String targetKey,
    required List<String> roster,
  }) {
    final target = targetKey.isEmpty ? '-' : targetKey;
    return 't3 $conversationId $senderX $action $target\n'
        '${roster.join(',')}';
  }

  static String composeReceipt({
    required ReceiptKind kind,
    required List<String> ids,
  }) {
    final tag = kind == ReceiptKind.delivered ? 'd1' : 'r1';
    final valid = ids.take(maxReceiptIds).where((id) => isHexOfLength(id, 32));
    return '$tag\n${valid.join(',')}';
  }

  /// Splits [ids] into one or more receipt frames so that no acknowledgement is
  /// silently dropped: a single frame carries at most [maxReceiptIds] ids.
  /// Malformed ids are skipped; an all-invalid batch produces no frame at all.
  static List<String> composeReceipts({
    required ReceiptKind kind,
    required List<String> ids,
  }) {
    final valid = ids.where((id) => isHexOfLength(id, 32)).toList();
    return [
      for (var start = 0; start < valid.length; start += maxReceiptIds)
        composeReceipt(
          kind: kind,
          ids: valid.skip(start).take(maxReceiptIds).toList(growable: false),
        ),
    ];
  }

  /// A media container for a 1:1 chat (`m1`) or a group chat (`m2`), with an
  /// optional quote folded in as one extra preview line. The data is the last
  /// body line, base64 of the file.
  static String composeMediaDirect({
    required String senderX,
    required String blobId,
    required MediaKind kind,
    required String mime,
    required int byteCount,
    required int durationMs,
    required String dataBase64,
    QuoteRef? quote,
  }) {
    final head = 'm1 $senderX $blobId ${_kindTag(kind)} '
        '$byteCount $durationMs';
    return _joinMedia(head, mime, dataBase64, quote);
  }

  /// Group variant of [composeMediaDirect]; [corrId] collapses every member
  /// copy into a single bubble exactly like a group text.
  static String composeMediaGroup({
    required String conversationId,
    required String corrId,
    required String senderX,
    required String blobId,
    required MediaKind kind,
    required String mime,
    required int byteCount,
    required int durationMs,
    required String dataBase64,
    QuoteRef? quote,
  }) {
    final head = 'm2 $conversationId $corrId $senderX $blobId '
        '${_kindTag(kind)} $byteCount $durationMs';
    return _joinMedia(head, mime, dataBase64, quote);
  }

  /// A chunked-file manifest for a 1:1 chat (`f1`). It is the bubble; the
  /// file itself follows as [FileChunkPayload]s.
  static String composeFileManifestDirect({
    required String senderX,
    required ChunkManifest manifest,
    QuoteRef? quote,
  }) {
    final head = 'f1 $senderX ${manifest.transferId} ${manifest.blobId} '
        '${manifest.kind} ${manifest.byteCount} ${manifest.chunkSize} '
        '${manifest.chunkCount} ${manifest.sha256} ${manifest.durationMs}';
    return _joinFileManifest(head, manifest.mime, quote);
  }

  /// Group variant of [composeFileManifestDirect].
  static String composeFileManifestGroup({
    required String conversationId,
    required String corrId,
    required String senderX,
    required ChunkManifest manifest,
    QuoteRef? quote,
  }) {
    final head = 'f2 $conversationId $corrId $senderX '
        '${manifest.transferId} ${manifest.blobId} ${manifest.kind} '
        '${manifest.byteCount} ${manifest.chunkSize} ${manifest.chunkCount} '
        '${manifest.sha256} ${manifest.durationMs}';
    return _joinFileManifest(head, manifest.mime, quote);
  }

  static String _joinFileManifest(
    String head,
    String mime,
    QuoteRef? quote,
  ) {
    if (quote == null ||
        !isHexOfLength(quote.refId, 32) ||
        !isHexOfLength(quote.authorX, 32)) {
      return '$head\n$mime';
    }
    final preview = _sanitizePreview(quote.preview);
    return '$head ${quote.refId} ${quote.authorX}\n$mime\n$preview';
  }

  /// One slice of a chunked file in a 1:1 chat (`c1`).
  static String composeFileChunkDirect({
    required String senderX,
    required FileChunk chunk,
  }) =>
      'c1 $senderX ${chunk.transferId} ${chunk.index} ${chunk.sha256}\n'
      '${chunk.dataBase64}';

  /// Group variant of [composeFileChunkDirect].
  static String composeFileChunkGroup({
    required String conversationId,
    required String senderX,
    required FileChunk chunk,
  }) =>
      'c2 $conversationId $senderX ${chunk.transferId} ${chunk.index} '
      '${chunk.sha256}\n${chunk.dataBase64}';

  /// Asks a holder for one slice of a chunked file (torrent-style pull).
  static String composeFileRequestDirect({
    required String senderX,
    required String transferId,
    required String blobId,
    required int index,
  }) =>
      'q1 $senderX $transferId $blobId $index';

  /// Group variant of [composeFileRequestDirect].
  static String composeFileRequestGroup({
    required String conversationId,
    required String senderX,
    required String transferId,
    required String blobId,
    required int index,
  }) =>
      'q2 $conversationId $senderX $transferId $blobId $index';

  static FileRequestPayload? _parseFileRequest(String header) {
    final isGroup = header.startsWith('q2 ');
    final parts = header.split(' ');
    // direct: tag sender transfer blob index (5)
    // group:  tag conv sender transfer blob index (6)
    if (parts.length != (isGroup ? 6 : 5)) return null;
    final tail = parts.sublist(1);
    final base = isGroup ? 1 : 0;
    final conversationId = isGroup ? tail[0] : '';
    final senderX = tail[base];
    final transferId = tail[base + 1];
    final blobId = tail[base + 2];
    final indexRaw = tail[base + 3];
    if (!isHexOfLength(senderX, 32) ||
        !isHexOfLength(transferId, 32) ||
        !isHexOfLength(blobId, 32)) {
      return null;
    }
    if (isGroup && !isHexOfLength(conversationId, 32)) return null;
    final index = int.tryParse(indexRaw);
    if (index == null || index < 0 || index >= maxTransferChunks) return null;
    return FileRequestPayload(
      conversationId: conversationId,
      senderX: senderX,
      transferId: transferId,
      blobId: blobId,
      index: index,
    );
  }

  static FileManifestPayload? _parseFileManifest(
    String header,
    String body,
  ) {
    final isGroup = header.startsWith('f2 ');
    final parts = header.split(' ');
    // direct: tag sender transfer blob kind bytes chunkSize chunks sha dur
    // group:  tag conv corr sender transfer blob kind bytes chunkSize chunks
    //         sha dur
    final fixed = isGroup ? 12 : 10;
    if (parts.length != fixed && parts.length != fixed + 2) return null;
    final quoted = parts.length == fixed + 2;
    final tail = parts.sublist(1);
    final base = isGroup ? 2 : 0;
    final conversationId = isGroup ? tail[0] : '';
    final corrId = isGroup ? tail[1] : '';
    final senderX = tail[base];
    final transferId = tail[base + 1];
    final blobId = tail[base + 2];
    final kindTag = tail[base + 3];
    final byteCountRaw = tail[base + 4];
    final chunkSizeRaw = tail[base + 5];
    final chunkCountRaw = tail[base + 6];
    final sha256 = tail[base + 7];
    final durationRaw = tail[base + 8];
    final refId = quoted ? tail[fixed - 1] : '';
    final authorX = quoted ? tail[fixed] : '';

    if (!isHexOfLength(senderX, 32) ||
        !isHexOfLength(transferId, 32) ||
        !isHexOfLength(blobId, 32) ||
        !isHexOfLength(sha256, 32)) {
      return null;
    }
    if (isGroup &&
        (!isHexOfLength(conversationId, 32) ||
            !isHexOfLength(corrId, 32))) {
      return null;
    }
    if (quoted && (!isHexOfLength(refId, 32) || !isHexOfLength(authorX, 32))) {
      return null;
    }
    final kind = _kindFromTag(kindTag);
    if (kind == null) return null;
    final byteCount = int.tryParse(byteCountRaw);
    final chunkSize = int.tryParse(chunkSizeRaw);
    final chunkCount = int.tryParse(chunkCountRaw);
    final durationMs = int.tryParse(durationRaw);
    if (byteCount == null ||
        chunkSize == null ||
        chunkCount == null ||
        durationMs == null) {
      return null;
    }
    if (byteCount <= 0 || byteCount > maxTransferBytes) return null;
    if (chunkSize <= 0 || chunkSize > transferChunkBytes) return null;
    if (chunkCount != (byteCount + chunkSize - 1) ~/ chunkSize ||
        chunkCount > maxTransferChunks) {
      return null;
    }
    if (durationMs < 0) return null;

    final nl = body.indexOf('\n');
    final mime = nl == -1 ? body : body.substring(0, nl);
    if (!_validMime(mime, kind)) return null;
    QuoteRef? quote;
    if (quoted) {
      if (nl == -1) return null;
      final preview = body.substring(nl + 1);
      // A quote carries one preview line and nothing else.
      if (preview.contains('\n')) return null;
      quote = QuoteRef(
        refId: refId,
        authorX: authorX,
        preview: _clampPreview(preview),
      );
    }
    return FileManifestPayload(
      conversationId: conversationId,
      corrId: corrId,
      senderX: senderX,
      manifest: ChunkManifest(
        transferId: transferId,
        blobId: blobId,
        kind: kind.name,
        mime: mime,
        byteCount: byteCount,
        chunkSize: chunkSize,
        chunkCount: chunkCount,
        sha256: sha256,
        durationMs: durationMs,
      ),
      quote: quote,
    );
  }

  static FileChunkPayload? _parseFileChunk(String header, String body) {
    final isGroup = header.startsWith('c2 ');
    final parts = header.split(' ');
    if (parts.length != (isGroup ? 6 : 5)) return null;
    final tail = parts.sublist(1);
    final base = isGroup ? 1 : 0;
    final conversationId = isGroup ? tail[0] : '';
    final senderX = tail[base];
    final transferId = tail[base + 1];
    final indexRaw = tail[base + 2];
    final sha256 = tail[base + 3];
    if (!isHexOfLength(senderX, 32) ||
        !isHexOfLength(transferId, 32) ||
        !isHexOfLength(sha256, 32)) {
      return null;
    }
    if (isGroup && !isHexOfLength(conversationId, 32)) return null;
    final index = int.tryParse(indexRaw);
    if (index == null || index < 0 || index >= maxTransferChunks) return null;
    if (body.isEmpty || body.contains('\n')) return null;
    if (body.length > (transferChunkBytes * 4 ~/ 3) + 8) return null;
    final List<int> decoded;
    try {
      decoded = base64Decode(body);
    } on FormatException {
      return null;
    }
    if (decoded.isEmpty || decoded.length > transferChunkBytes) return null;
    return FileChunkPayload(
      conversationId: conversationId,
      senderX: senderX,
      chunk: FileChunk(
        transferId: transferId,
        index: index,
        dataBase64: body,
        sha256: sha256,
      ),
    );
  }

  static String _joinMedia(
    String head,
    String mime,
    String dataBase64,
    QuoteRef? quote,
  ) {
    if (quote == null ||
        !isHexOfLength(quote.refId, 32) ||
        !isHexOfLength(quote.authorX, 32)) {
      return '$head\n$mime\n$dataBase64';
    }
    final preview = _sanitizePreview(quote.preview);
    final ref = '${quote.refId} ${quote.authorX}';
    return '$head $ref\n$mime\n$preview\n$dataBase64';
  }

  static String _kindTag(MediaKind kind) => switch (kind) {
        MediaKind.voice => _voiceTag,
        MediaKind.photo => _photoTag,
        MediaKind.video => _videoTag,
        MediaKind.file => _fileTag,
      };

  /// Parses a media header and body strictly. Anything inconsistent — an
  /// unknown kind, a MIME outside its kind's family, a byte count that
  /// disagrees with the decoded data or exceeds [maxMediaBlobBytes] — makes
  /// the container plain text, so a hostile sender can neither crash the
  /// parser nor make a message disappear.
  static MediaPayload? _parseMedia(String header, String body) {
    final parts = header.split(' ');
    final isGroup = header.startsWith('m2 ');
    // Field layout after the tag:
    //   direct: sender blob kind bytes durationMs [refId authorX]
    //   group:  conv corr sender blob kind bytes durationMs [refId authorX]
    final fixed = isGroup ? 7 : 5;
    if (parts.length != fixed + 1 && parts.length != fixed + 3) return null;
    final quoted = parts.length == fixed + 3;
    final tail = parts.sublist(1);

    final conversationId = isGroup ? tail[0] : '';
    final corrId = isGroup ? tail[1] : '';
    final senderX = tail[isGroup ? 2 : 0];
    final blobId = tail[isGroup ? 3 : 1];
    final kindTag = tail[isGroup ? 4 : 2];
    final byteCountRaw = tail[isGroup ? 5 : 3];
    final durationRaw = tail[isGroup ? 6 : 4];
    final refId = quoted ? tail[fixed] : '';
    final authorX = quoted ? tail[fixed + 1] : '';

    final kind = _kindFromTag(kindTag);
    if (kind == null) return null;
    if (!isHexOfLength(senderX, 32) || !isHexOfLength(blobId, 32)) return null;
    if (isGroup && !isHexOfLength(conversationId, 32)) return null;
    if (isGroup && !isHexOfLength(corrId, 32)) return null;
    if (quoted && (!isHexOfLength(refId, 32) || !isHexOfLength(authorX, 32))) {
      return null;
    }

    final byteCount = int.tryParse(byteCountRaw);
    final durationMs = int.tryParse(durationRaw);
    if (byteCount == null || durationMs == null) return null;
    if (byteCount <= 0 || byteCount > maxMediaBlobBytes) return null;
    if (durationMs < 0) return null;

    final nl = body.indexOf('\n');
    if (nl == -1) return null;
    final mime = body.substring(0, nl);
    var rest = body.substring(nl + 1);
    QuoteRef? quote;
    if (quoted) {
      final nl2 = rest.indexOf('\n');
      if (nl2 == -1) return null;
      quote = QuoteRef(
        refId: refId,
        authorX: authorX,
        preview: _clampPreview(rest.substring(0, nl2)),
      );
      rest = rest.substring(nl2 + 1);
    }
    if (!_validMime(mime, kind)) return null;
    if (!_validData(rest, byteCount)) return null;

    return MediaPayload(
      conversationId: conversationId,
      corrId: corrId,
      senderX: senderX,
      blobId: blobId,
      kind: kind,
      mime: mime,
      byteCount: byteCount,
      durationMs: durationMs,
      dataBase64: rest,
      quote: quote,
    );
  }

  static MediaKind? _kindFromTag(String tag) {
    if (tag == _voiceTag) return MediaKind.voice;
    if (tag == _photoTag) return MediaKind.photo;
    if (tag == _videoTag) return MediaKind.video;
    if (tag == _fileTag) return MediaKind.file;
    return null;
  }

  /// The MIME must belong to the family its kind claims: a voice container
  /// carries `audio/*`, a photo one of the accepted image types.
  static bool _validMime(String mime, MediaKind kind) {
    if (mime.isEmpty || mime.length > maxMediaMimeLength) return false;
    return switch (kind) {
      MediaKind.voice => mediaAudioMimePrefixes.any(mime.startsWith),
      MediaKind.photo => mediaImageMimeTypes.contains(mime),
      MediaKind.video => mediaVideoMimeTypes.contains(mime),
      MediaKind.file => _fileMime.hasMatch(mime),
    };
  }

  static bool _validData(String data, int expected) {
    if (data.isEmpty) return false;
    try {
      return base64Decode(data).length == expected;
    } catch (_) {
      return false;
    }
  }

  static (QuoteRef, String)? _splitQuote(
    String refId,
    String authorX,
    String body,
  ) {
    final nl = body.indexOf('\n');
    if (nl == -1) return null;
    final preview = _clampPreview(body.substring(0, nl));
    final text = body.substring(nl + 1);
    return (
      QuoteRef(refId: refId, authorX: authorX, preview: preview),
      text,
    );
  }

  static String _clampPreview(String preview) {
    if (preview.runes.length <= maxQuotePreviewChars) return preview;
    return String.fromCharCodes(preview.runes.take(maxQuotePreviewChars));
  }

  static String _sanitizePreview(String preview) {
    final flat = preview.replaceAll('\n', ' ').replaceAll('\r', ' ');
    if (flat.runes.length <= maxQuotePreviewChars) return flat;
    return String.fromCharCodes(flat.runes.take(maxQuotePreviewChars));
  }

  static List<String> _parseIds(String body) {
    final parts = body.split(',');
    final ids = <String>[];
    for (final part in parts) {
      if (ids.length >= maxReceiptIds) break;
      // A receipt truncated on the wire keeps the ids it did carry; the first
      // malformed entry ends the list instead of voiding the whole frame.
      if (!isHexOfLength(part, 32)) break;
      ids.add(part);
    }
    return ids;
  }
}

/// A chunked-file manifest. It renders as the media bubble once the file has
/// been assembled, and as a progress tile while chunks are still arriving.
class FileManifestPayload extends MessagePayload {
  final String conversationId;
  final String corrId;
  final String senderX;
  final ChunkManifest manifest;
  final QuoteRef? quote;

  const FileManifestPayload({
    required this.conversationId,
    required this.corrId,
    required this.senderX,
    required this.manifest,
    this.quote,
  });

  /// The media kind parsed from the wire tag.
  MediaKind get kind => MessagePayload._kindFromTag(manifest.kind)!;
}

/// A request for one slice of a chunked file. It lets a recipient pull the
/// missing parts from the sender or from any group member that already holds
/// them, instead of the sender pushing the whole file.
class FileRequestPayload extends MessagePayload {
  final String conversationId;
  final String senderX;
  final String transferId;
  final String blobId;
  final int index;

  const FileRequestPayload({
    required this.conversationId,
    required this.senderX,
    required this.transferId,
    required this.blobId,
    required this.index,
  });
}

/// One slice of a chunked file. Never renders as a bubble: the receiving
/// device feeds it to its transfer assembler.
class FileChunkPayload extends MessagePayload {
  final String conversationId;
  final String senderX;
  final FileChunk chunk;

  const FileChunkPayload({
    required this.conversationId,
    required this.senderX,
    required this.chunk,
  });
}

/// A malformed known protocol frame. It is delivered and stored like any other
/// envelope but never rendered and never acknowledged as a chat message.
class DroppedPayload extends MessagePayload {
  const DroppedPayload();
}

class TextPayload extends MessagePayload {
  final String text;

  const TextPayload(this.text);
}

class DirectPayload extends MessagePayload {
  final String senderX;
  final String text;

  /// Reply target, or `null` for a plain message.
  final QuoteRef? quote;

  const DirectPayload({
    required this.senderX,
    required this.text,
    this.quote,
  });
}

class GroupMessagePayload extends MessagePayload {
  final String conversationId;
  final String corrId;
  final String senderX;
  final GroupContainerKind kind;
  final String value;

  /// Roster action (`a` add, `r` remove, `p` promote, `d` demote, `c`
  /// created) for [GroupContainerKind.roster]; empty for messages and titles.
  final String rosterAction;

  /// Full roster carried by a `t3` sync, sorted; empty for other kinds.
  final List<String> rosterKeys;

  /// Reply target, or `null` for a plain message.
  final QuoteRef? quote;

  const GroupMessagePayload({
    required this.conversationId,
    required this.corrId,
    required this.senderX,
    required this.kind,
    required this.value,
    this.rosterAction = '',
    this.rosterKeys = const [],
    this.quote,
  });
}

class ReceiptPayload extends MessagePayload {
  final ReceiptKind kind;
  final List<String> ids;

  const ReceiptPayload({required this.kind, required this.ids});
}

/// One voice note or photo travelling in a single envelope.
///
/// The container is generated by [MessagePayload.composeMediaDirect] /
/// [MessagePayload.composeMediaGroup] and only ever produced by
/// [MessagePayload.parse] after a strict validation pass.
class MediaPayload extends MessagePayload {
  /// Empty for a 1:1 chat, the conversation key for a group.
  final String conversationId;

  /// Fan-out correlation id; empty for a 1:1 chat.
  final String corrId;

  final String senderX;

  /// Content address of the file (32-byte hex).
  final String blobId;

  final MediaKind kind;

  /// MIME type, guaranteed to be inside [kind]'s accepted family.
  final String mime;

  /// Decoded size of the file; matches [dataBase64] by construction.
  final int byteCount;

  /// Playback length in milliseconds; `0` for a photo.
  final int durationMs;

  final String dataBase64;

  /// Reply target, or `null` for a plain message.
  final QuoteRef? quote;

  const MediaPayload({
    required this.conversationId,
    required this.corrId,
    required this.senderX,
    required this.blobId,
    required this.kind,
    required this.mime,
    required this.byteCount,
    required this.durationMs,
    required this.dataBase64,
    this.quote,
  });

  Uint8List get bytes => base64Decode(dataBase64);
}
