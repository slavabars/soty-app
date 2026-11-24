import 'dart:async';
import 'dart:typed_data';

import 'package:dtm_app/core/transport/length_prefixed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('framePayload', () {
    test('prefixes the payload with a big-endian uint32 length', () {
      final framed = framePayload(const [1, 2, 3]);
      expect(framed.length, 7);
      expect(framed.sublist(0, 4), [0, 0, 0, 3]);
      expect(framed.sublist(4), [1, 2, 3]);
    });
  });

  group('frameLengthFromHeader', () {
    test('returns null for short headers', () {
      expect(frameLengthFromHeader(const [0, 0, 0]), isNull);
    });

    test('parses a valid length', () {
      expect(frameLengthFromHeader(const [0, 0, 0, 5], maxBytes: 10), 5);
    });

    test('rejects lengths above the cap', () {
      final header = Uint8List(4);
      ByteData.sublistView(header).setUint32(0, 0xFFFFFFFF);
      expect(frameLengthFromHeader(header, maxBytes: 10), isNull);
    });
  });

  group('LengthPrefixedDecoder', () {
    Future<List<List<int>>> decode(
      List<List<int>> chunks, {
      int? maxBytes,
    }) async {
      final source = StreamController<List<int>>();
      final frames = <List<int>>[];
      final done = Completer<void>();
      final stream = source.stream.transform(
        LengthPrefixedDecoder(maxBytes: maxBytes ?? 64 * 1024),
      );
      stream.listen(
        frames.add,
        onDone: done.complete,
        onError: (_) => done.complete(),
      );
      for (final chunk in chunks) {
        source.add(chunk);
      }
      await source.close();
      await done.future;
      return frames;
    }

    test('decodes a single frame', () async {
      final frames = await decode([
        framePayload(const [1, 2, 3]),
      ]);
      expect(frames, [
        [1, 2, 3],
      ]);
    });

    test('reassembles frames split across many chunks', () async {
      final framed = framePayload(const [9, 8, 7, 6, 5]);
      final chunks = [
        for (final b in framed) [b],
      ];
      final frames = await decode(chunks);
      expect(frames, [
        [9, 8, 7, 6, 5],
      ]);
    });

    test('decodes multiple frames from one chunk', () async {
      final frames = await decode([
        [
          ...framePayload(const [1]),
          ...framePayload(const [2, 2]),
        ],
      ]);
      expect(frames, [
        [1],
        [2, 2],
      ]);
    });

    test('supports empty frames', () async {
      final frames = await decode([framePayload(const [])]);
      expect(frames, [<int>[]]);
    });

    test('aborts the stream on an oversized declared length', () async {
      final header = Uint8List(4);
      ByteData.sublistView(header).setUint32(0, 0xFFFFFFFF);
      final frames = await decode([header], maxBytes: 16);
      expect(frames, isEmpty);
    });

    test('stops emitting after a corrupt header', () async {
      final frames = await decode([
        framePayload(const [1]),
        Uint8List.fromList(const [0, 0, 0, 200]),
        framePayload(const [2]),
      ], maxBytes: 16);
      expect(frames, [
        [1],
      ]);
    });
  });
}
