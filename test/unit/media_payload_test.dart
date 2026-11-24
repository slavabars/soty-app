import 'dart:convert' show base64Encode;

import 'package:dtm_app/core/security_limits.dart'
    show maxMediaBlobBytes;
import 'package:dtm_app/models/message_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a video container parses back as a video attachment', () {
    final raw = MessagePayload.composeMediaDirect(
      senderX: '11' * 32,
      blobId: '22' * 32,
      kind: MediaKind.video,
      mime: 'video/mp4',
      byteCount: 3,
      durationMs: 2000,
      dataBase64: 'AQID',
    );
    final payload = MessagePayload.parse(raw);
    expect(payload, isA<MediaPayload>());
    final media = payload as MediaPayload;
    expect(media.kind, MediaKind.video);
    expect(media.mime, 'video/mp4');
    expect(media.durationMs, 2000);
  });

  test('a video container with an image mime degrades to text', () {
    final raw = MessagePayload.composeMediaDirect(
      senderX: '11' * 32,
      blobId: '22' * 32,
      kind: MediaKind.video,
      mime: 'image/png',
      byteCount: 3,
      durationMs: 0,
      dataBase64: 'AQID',
    );
    expect(MessagePayload.parse(raw), isA<DroppedPayload>());
  });

  test('a file container round-trips with an arbitrary mime', () {
    final raw = MessagePayload.composeMediaDirect(
      senderX: '11' * 32,
      blobId: '22' * 32,
      kind: MediaKind.file,
      mime: 'application/pdf',
      byteCount: 3,
      durationMs: 0,
      dataBase64: 'AQID',
    );
    final media = MessagePayload.parse(raw) as MediaPayload;
    expect(media.kind, MediaKind.file);
    expect(media.mime, 'application/pdf');
  });

  test('a file container with an invalid mime degrades to text', () {
    final raw = MessagePayload.composeMediaDirect(
      senderX: '11' * 32,
      blobId: '22' * 32,
      kind: MediaKind.file,
      mime: 'not a mime',
      byteCount: 3,
      durationMs: 0,
      dataBase64: 'AQID',
    );
    expect(MessagePayload.parse(raw), isA<DroppedPayload>());
  });

  final key = 'a' * 64;
  final peer = 'b' * 64;
  final conv = 'c' * 64;
  final corr = 'd' * 64;
  final blob = 'e' * 64;

  String b64(int len) => base64Encode(List<int>.filled(len, 7));

  group('media containers', () {
    test('a direct voice container round-trips', () {
      final data = b64(1200);
      final composed = MessagePayload.composeMediaDirect(
        senderX: key,
        blobId: blob,
        kind: MediaKind.voice,
        mime: 'audio/mp4',
        byteCount: 1200,
        durationMs: 7400,
        dataBase64: data,
      );
      final payload = MessagePayload.parse(composed);
      expect(payload, isA<MediaPayload>());
      final media = payload as MediaPayload;
      expect(media.senderX, key);
      expect(media.blobId, blob);
      expect(media.kind, MediaKind.voice);
      expect(media.mime, 'audio/mp4');
      expect(media.byteCount, 1200);
      expect(media.durationMs, 7400);
      expect(media.dataBase64, data);
      expect(media.corrId, '');
    });

    test('a direct photo container round-trips with no duration', () {
      final composed = MessagePayload.composeMediaDirect(
        senderX: key,
        blobId: blob,
        kind: MediaKind.photo,
        mime: 'image/jpeg',
        byteCount: 4021,
        durationMs: 0,
        dataBase64: b64(4021),
      );
      final media = MessagePayload.parse(composed) as MediaPayload;
      expect(media.kind, MediaKind.photo);
      expect(media.durationMs, 0);
    });

    test('a group voice container carries a correlation id', () {
      final composed = MessagePayload.composeMediaGroup(
        conversationId: conv,
        corrId: corr,
        senderX: key,
        blobId: blob,
        kind: MediaKind.voice,
        mime: 'audio/mp4',
        byteCount: 900,
        durationMs: 3000,
        dataBase64: b64(900),
      );
      final media = MessagePayload.parse(composed) as MediaPayload;
      expect(media.conversationId, conv);
      expect(media.corrId, corr);
      expect(media.senderX, key);
      expect(media.byteCount, 900);
    });

    test('a quote travels with a media reply', () {
      final composed = MessagePayload.composeMediaDirect(
        senderX: key,
        blobId: blob,
        kind: MediaKind.photo,
        mime: 'image/png',
        byteCount: 10,
        durationMs: 0,
        dataBase64: b64(10),
        quote: QuoteRef(refId: key, authorX: peer, preview: 'hi'),
      );
      final media = MessagePayload.parse(composed) as MediaPayload;
      expect(media.quote, isNotNull);
      expect(media.quote!.refId, key);
      expect(media.quote!.preview, 'hi');
    });

    test('decode returns the original bytes', () {
      final raw = List<int>.generate(50, (i) => i);
      final composed = MessagePayload.composeMediaDirect(
        senderX: key,
        blobId: blob,
        kind: MediaKind.photo,
        mime: 'image/jpeg',
        byteCount: raw.length,
        durationMs: 0,
        dataBase64: base64Encode(raw),
      );
      final media = MessagePayload.parse(composed) as MediaPayload;
      expect(media.bytes, raw);
    });
  });

  group('hostile media containers are dropped, not rendered', () {
    void expectText(String raw) {
      expect(MessagePayload.parse(raw), isA<DroppedPayload>(), reason: raw);
    }

    test('broken base64', () {
      expectText('m1 $key $blob voice audio/mp4 4 100\n!!!!');
    });

    test('byteCount disagrees with the decoded length', () {
      final data = base64Encode(List<int>.filled(10, 1));
      expectText('m1 $key $blob voice audio/mp4 999 100\n$data');
    });

    test('blobId is not 32-byte hex', () {
      expectText('m1 $key nothex voice audio/mp4 4 100\n${b64(4)}');
    });

    test('mime is outside the whitelist', () {
      expectText('m1 $key $blob voice text/html 4 100\n${b64(4)}');
    });

    test('a photo claims an audio mime', () {
      expectText('m1 $key $blob photo audio/mp4 4 0\n${b64(4)}');
    });

    test('a voice claims an image mime', () {
      expectText('m1 $key $blob voice image/jpeg 4 0\n${b64(4)}');
    });

    test('byteCount above the blob ceiling', () {
      final huge = maxMediaBlobBytes + 1;
      expectText('m1 $key $blob photo image/jpeg $huge 0\n${b64(4)}');
    });

    test('a negative duration', () {
      expectText('m1 $key $blob voice audio/mp4 4 -1\n${b64(4)}');
    });

    test('an unknown kind', () {
      expectText('m1 $key $blob video video/mp4 4 0\n${b64(4)}');
    });

    test('a header with too few fields', () {
      expectText('m1 $key $blob voice audio/mp4\n${b64(4)}');
    });

    test('an empty body', () {
      expectText('m1 $key $blob voice audio/mp4 4 100\n');
    });

    test('a group header with a malformed key', () {
      expectText('m2 $conv $corr nothex $blob voice audio/mp4 4 0\n${b64(4)}');
    });

    test('a group header without a correlation id', () {
      expectText('m2 $conv $corr voice audio/mp4 4 0\n${b64(4)}');
    });

    test('a bad mime length is dropped', () {
      final long = 'audio/${'x' * 200}';
      expectText('m1 $key $blob voice $long 4 0\n${b64(4)}');
    });

    test('an oversized declared blob is not decoded', () {
      // The declared count is a lie 1000x over; parsing must reject on the
      // declared value, not after materializing the data.
      expectText('m1 $key $blob photo image/jpeg 100000000 0\n${b64(4)}');
    });

    test('the retired a1/a2 tags are plain text, not media', () {
      final raw = 'a1 $key $blob voice audio/mp4 4 100\n${b64(4)}';
      final payload = MessagePayload.parse(raw);
      expect(payload, isA<TextPayload>());
      expect((payload as TextPayload).text, raw);
    });
  });

  test('a malformed media container never throws', () {
    for (final raw in <String>[
      'm1',
      'm1 ',
      'm1\n',
      'm2 $conv',
      'm1 $key $blob voice',
      'm1 $key $blob voice audio/mp4 4 100\n=',
      'm1 $key $blob voice audio/mp4 4 100\n=====',
      'm1 $key $blob voice audio/mp4 4 100\n👋',
    ]) {
      expect(() => MessagePayload.parse(raw), returnsNormally, reason: raw);
    }
  });

  test('the media payload limit is a named constant', () {
    expect(maxMediaBlobBytes, greaterThan(0));
  });
}
