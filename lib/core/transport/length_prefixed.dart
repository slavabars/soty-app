import 'dart:async';
import 'dart:typed_data';

import '../security_limits.dart' as limits;

/// Length-prefixed framing shared by the P2P and gossip protocols.
///
/// Wire format: `uint32BE(len) || payload`.
Uint8List framePayload(List<int> payload) {
  final out = Uint8List(4 + payload.length);
  final bd = ByteData.sublistView(out);
  bd.setUint32(0, payload.length);
  out.setRange(4, out.length, payload);
  return out;
}

/// Parses the length header with a ceiling; `null` when the header lies
/// outside `[0, maxBytes]` (treat as protocol violation → abort stream).
int? frameLengthFromHeader(
  List<int> header, {
  int maxBytes = limits.maxFrameBytes,
}) {
  if (header.length < 4) return null;
  final length = ByteData.sublistView(Uint8List.fromList(header)).getUint32(0);
  if (length < 0 || length > maxBytes) return null;
  return length;
}

/// Decodes a byte stream into complete frames.
///
/// Frames longer than [maxBytes] abort the stream (the consumer is told via
/// the controller closing) — a hostile peer can never buffer unboundedly.
class LengthPrefixedDecoder
    extends StreamTransformerBase<List<int>, List<int>> {
  final int _maxBytes;
  final StreamController<List<int>> _buffer = StreamController();

  LengthPrefixedDecoder({int maxBytes = limits.maxFrameBytes})
    : _maxBytes = maxBytes;

  @override
  Stream<List<int>> bind(Stream<List<int>> source) {
    Future<void> deliver() async {
      var pending = <int>[];
      await for (final chunk in source) {
        if (_buffer.isClosed) return;
        pending.addAll(chunk);
        while (pending.length >= 4) {
          final length = frameLengthFromHeader(pending, maxBytes: _maxBytes);
          if (length == null) {
            // Corrupt or oversized header — abort the stream to stop the peer
            // from stalling/OOMing us with a huge declared length.
            await _buffer.close();
            return;
          }
          if (pending.length < 4 + length) break;
          final frame = pending.sublist(4, 4 + length);
          pending = pending.sublist(4 + length);
          _buffer.add(frame);
        }
      }
      await _buffer.close();
    }

    deliver();
    return _buffer.stream;
  }
}
