import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/media/chunked_transfer.dart';
import 'package:dtm_app/core/media/media_capture.dart';
import 'package:dtm_app/core/media/media_store.dart';
import 'package:dtm_app/core/security_limits.dart'
    show
        autoDownloadBytes,
        maxMediaBlobBytes,
        minVoiceMs,
        transferChunkBytes;
import 'package:dtm_app/core/transport/transport.dart';
import 'package:dtm_app/features/messenger/media_bubble.dart';
import 'package:dtm_app/models/message_payload.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fixture.dart';

/// A 2×2 red PNG: small enough to inline, real enough for the image codec.
final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEElEQVR4nGP4z8AARAwQ'
  'CgAf7gP9i18U1AAAAABJRU5ErkJggg==',
);

class _FakeRecorder implements VoiceRecorder {
  bool allowed = true;
  bool canStart = true;
  Uint8List? captured;
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;

  @override
  Future<bool> ensurePermission() async => allowed;

  @override
  Future<bool> start() async {
    startCalls++;
    return canStart;
  }

  @override
  Future<Uint8List?> stop() async {
    stopCalls++;
    return captured;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }
}

class _FakePicker implements PhotoPicker {
  PickedPhoto? photo;
  bool throwOnPick = false;
  bool lastCamera = false;

  @override
  Future<PickedPhoto?> pick({bool camera = false}) async {
    if (throwOnPick) throw StateError('picker is broken');
    lastCamera = camera;
    return photo;
  }
}

class _FakeFilePicker implements FilePicker {
  PickedFile? file;
  bool throwOnPick = false;

  @override
  Future<PickedFile?> pick() async {
    if (throwOnPick) throw StateError('picker is broken');
    return file;
  }
}

class _FakeVideoPicker implements VideoPicker {
  PickedVideo? video;
  bool throwOnPick = false;
  bool lastCamera = false;

  @override
  Future<PickedVideo?> pick({bool camera = false}) async {
    if (throwOnPick) throw StateError('picker is broken');
    lastCamera = camera;
    return video;
  }
}

class _FakePlayer implements VoicePlayer {
  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();
  final List<Uint8List> played = [];
  bool disposed = false;

  @override
  Stream<PlaybackState> get states => _states.stream;

  @override
  Future<void> play(Uint8List bytes, {required String mimeType}) async {
    played.add(bytes);
    _states.add(PlaybackState.playing);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    disposed = true;
    await _states.close();
  }
}

class _FakeMedia {
  final recorder = _FakeRecorder();
  final picker = _FakePicker();
  final videoPicker = _FakeVideoPicker();
  final filePicker = _FakeFilePicker();
  final players = <_FakePlayer>[];

  MediaServices get services => MediaServices(
        recorder: recorder,
        picker: picker,
        videoPicker: videoPicker,
        filePicker: filePicker,
        newPlayer: () {
          final player = _FakePlayer();
          players.add(player);
          return player;
        },
      );
}

/// Delivers a media container from the fixture's remote peer.
Future<void> sendInboundMedia(
  Fixture f, {
  required MediaKind kind,
  required String mime,
  required Uint8List bytes,
  int durationMs = 0,
}) async {
  final envelope = await createEnvelopeForPubKey(
    sender: f.remote,
    recipientX25519PubKeyHex: f.controller.myXPubKey,
    plaintext: MessagePayload.composeMediaDirect(
      senderX: await f.remote.x25519PublicKeyHex,
      blobId: 'a' * 64,
      kind: kind,
      mime: mime,
      byteCount: bytes.length,
      durationMs: durationMs,
      dataBase64: base64Encode(bytes),
    ),
  );
  await f.processor.process(envelope, source: TransportSource.mesh, hops: 0);
}

Future<void> sendInboundManifest(
  Fixture f,
  ChunkManifest manifest,
) async {
  final envelope = await createEnvelopeForPubKey(
    sender: f.remote,
    recipientX25519PubKeyHex: f.controller.myXPubKey,
    plaintext: MessagePayload.composeFileManifestDirect(
      senderX: await f.remote.x25519PublicKeyHex,
      manifest: manifest,
    ),
  );
  await f.processor.process(envelope, source: TransportSource.mesh, hops: 0);
}

Future<void> attach(
  WidgetTester tester,
  String option,
) async {
  await tester.tap(find.byIcon(Icons.attach_file));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, option));
  await tester.pump();
}

void main() {
  late Directory mediaDir;

  setUp(() async {
    mediaDir = await Directory.systemTemp.createTemp('soty_chat_media');
    MediaStore.overrideRoot = mediaDir;
  });

  tearDown(() async {
    MediaStore.overrideRoot = null;
    await mediaDir.delete(recursive: true);
  });

  group('recording', () {
    testWidgets('holding the microphone shows the seconds left',
        (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia();

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.mic)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Recording… 0:00'), findsOneWidget);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('the countdown counts down while the take runs',
        (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia();

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.mic)),
      );
      await tester.pump();
      expect(find.text('Recording… 0:00'), findsOneWidget);

      // The countdown is measured with a real stopwatch, so the wait has to
      // happen outside the fake clock; the tick that repaints the banner is
      // a fake-clock timer, so it fires on the next pump.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Recording… 0:01'), findsOneWidget);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('a refused microphone permission warns and records nothing',
        (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia()..recorder.allowed = false;

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.mic)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Microphone permission is required'), findsOneWidget);
      expect(media.recorder.startCalls, 0);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('a recorder that refuses to start warns', (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia()..recorder.canStart = false;

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.mic)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Recording failed'), findsOneWidget);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('a take shorter than the floor is refused', (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia()
        ..recorder.captured = Uint8List.fromList(List<int>.filled(64, 1));

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.mic)),
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump();

      expect(find.text('Voice message is too short'), findsOneWidget);
      expect(find.byType(MediaBubble), findsNothing);
      final messages = await f.controller.messagesFor(f.peerX);
      expect(messages.where((m) => m.media != null), isEmpty);
    });

    testWidgets('a take longer than the floor is sent as a voice bubble',
        (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia()
        ..recorder.captured = Uint8List.fromList(List<int>.filled(64, 2));

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.mic)),
      );
      await tester.pump();

      // The floor is 500 ms of real time, and the take is measured with a
      // real stopwatch, so the wait has to happen outside the fake clock.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 700)),
      );

      await gesture.up();
      await tester.pump();
      await tester.pump();

      expect(find.byType(MediaBubble), findsOneWidget);
      final messages = await f.controller.messagesFor(f.peerX);
      final sent = messages.where((m) => m.media != null).toList();
      expect(sent, hasLength(1));
      expect(sent.single.media!.kind, MediaKind.voice);
      expect(sent.single.media!.durationMs, greaterThanOrEqualTo(minVoiceMs));
    });

    testWidgets('a recording cancelled from the banner is thrown away',
        (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia()
        ..recorder.captured = Uint8List.fromList(List<int>.filled(64, 3));

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.mic)),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(media.recorder.cancelCalls, 1);
      expect(find.byType(MediaBubble), findsNothing);
    });
  });

  group('photos', () {
    testWidgets('an oversized photo warns and is not sent', (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia()
        ..picker.photo = PickedPhoto(
          bytes: Uint8List(maxMediaBlobBytes + 1),
          mime: 'image/jpeg',
        );

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      await attach(tester, 'Photo');
      await tester.pump();
      await tester.pump();

      expect(find.text('Photo is too large (max 128 KB)'), findsOneWidget);
      expect(find.byType(MediaBubble), findsNothing);
      final messages = await f.controller.messagesFor(f.peerX);
      expect(messages.where((m) => m.media != null), isEmpty);
    });

    testWidgets('an unsupported photo format warns and is not sent',
        (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia()
        ..picker.photo = PickedPhoto(bytes: _pngBytes, mime: 'image/gif');

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      await attach(tester, 'Photo');
      await tester.pump();
      await tester.pump();

      expect(find.text('Unsupported photo format'), findsOneWidget);
      expect(find.byType(MediaBubble), findsNothing);
    });

    testWidgets('a broken picker leaves the chat alone', (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia()..picker.throwOnPick = true;

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      await attach(tester, 'Photo');
      await tester.pump();
      await tester.pump();

      expect(find.byType(MediaBubble), findsNothing);
      final messages = await f.controller.messagesFor(f.peerX);
      expect(messages.where((m) => m.media != null), isEmpty);
    });

    testWidgets('a picked photo is sent and renders as an image',
        (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia()
        ..picker.photo = PickedPhoto(bytes: _pngBytes, mime: 'image/png');

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      await attach(tester, 'Photo');
      await tester.pump();
      await tester.pump();

      expect(find.byType(MediaBubble), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Photo unavailable'), findsNothing);
      final messages = await f.controller.messagesFor(f.peerX);
      final sent = messages.where((m) => m.media != null).toList();
      expect(sent, hasLength(1));
      expect(sent.single.media!.kind, MediaKind.photo);
      expect(sent.single.media!.mime, 'image/png');
    });
  });


  group('videos', () {
    Uint8List videoBytes(int len) =>
        Uint8List.fromList(List<int>.generate(len, (i) => (i * 13) % 251));

    testWidgets('a foreign video mime warns and is not sent', (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia()
        ..videoPicker.video = PickedVideo(
          bytes: videoBytes(64),
          mime: 'video/x-msvideo',
        );

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      await attach(tester, 'Video');
      await tester.pump();
      await tester.pump();

      expect(find.text('Unsupported video format'), findsOneWidget);
      expect(find.byType(MediaBubble), findsNothing);
    });

    testWidgets('a small video is inlined and renders as a video bubble',
        (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia()
        ..videoPicker.video = PickedVideo(
          bytes: videoBytes(4096),
          mime: 'video/mp4',
        );

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      await attach(tester, 'Video');
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(MediaBubble), findsOneWidget);
      final messages = await f.controller.messagesFor(f.peerX);
      final sent = messages.where((m) => m.media != null).toList();
      expect(sent, hasLength(1));
      expect(sent.single.media!.kind, MediaKind.video);
      expect(sent.single.media!.byteCount, 4096);
    });

    testWidgets('a large video is sent in slices and renders once',
        (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia()
        ..videoPicker.video = PickedVideo(
          bytes: videoBytes(maxMediaBlobBytes + 200 * 1024),
          mime: 'video/mp4',
        );

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      await attach(tester, 'Video');
      await tester.pump();
      for (var i = 0; i < 60; i++) {
        final current = await f.controller.messagesFor(f.peerX);
        if (current.any((m) => m.media != null)) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
      await tester.pump();

      final messages = await f.controller.messagesFor(f.peerX);
      final sent = messages.where((m) => m.media != null).toList();
      expect(sent, hasLength(1));
      expect(sent.single.media!.byteCount, maxMediaBlobBytes + 200 * 1024);
      expect(find.byType(MediaBubble), findsOneWidget);
    });
  });


  group('large transfers', () {
    testWidgets('a file over 100 MB offers a download button', (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia();
      final byteCount = autoDownloadBytes + 1;
      final manifest = ChunkManifest(
        transferId: 'ab' * 32,
        blobId: 'bc' * 32,
        kind: 'video',
        mime: 'video/mp4',
        byteCount: byteCount,
        chunkSize: transferChunkBytes,
        chunkCount: (byteCount + transferChunkBytes - 1) ~/ transferChunkBytes,
        sha256: 'cd' * 32,
        durationMs: 0,
      );
      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await sendInboundManifest(f, manifest);
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Download'), findsOneWidget);
      expect(find.textContaining('MB'), findsOneWidget);

      await tester.tap(find.textContaining('Download'));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.textContaining('Download'), findsNothing);
      final messages = await f.controller.messagesFor(f.peerX);
      expect(messages.single.transfer!.started, isTrue);
    });
  });


  group('attachments', () {
    testWidgets('a photo can come from the camera', (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia()
        ..picker.photo = PickedPhoto(bytes: _pngBytes, mime: 'image/png');
      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      await attach(tester, 'Take photo');
      await tester.pump();
      await tester.pump();

      expect(media.picker.lastCamera, isTrue);
      final messages = await f.controller.messagesFor(f.peerX);
      expect(messages.where((m) => m.media != null), hasLength(1));
    });

    testWidgets('a video can come from the camera', (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia()
        ..videoPicker.video = PickedVideo(
          bytes: Uint8List(4096),
          mime: 'video/mp4',
        );
      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      await attach(tester, 'Record video');
      await tester.pump();
      await tester.pump();

      expect(media.videoPicker.lastCamera, isTrue);
      final messages = await f.controller.messagesFor(f.peerX);
      expect(messages.where((m) => m.media != null), hasLength(1));
    });

    testWidgets('an arbitrary file is sent and offers a save button',
        (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia()
        ..filePicker.file = PickedFile(
          bytes: Uint8List(4096),
          mime: 'application/pdf',
        );
      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      await attach(tester, 'File');
      await tester.pump();
      await tester.pump();

      final messages = await f.controller.messagesFor(f.peerX);
      final sent = messages.where((m) => m.media != null).toList();
      expect(sent, hasLength(1));
      expect(sent.single.media!.kind, MediaKind.file);
      expect(find.byIcon(Icons.insert_drive_file_outlined), findsWidgets);
      expect(find.byIcon(Icons.download), findsOneWidget);
    });
  });

  group('inbound bubbles', () {
    testWidgets('an inbound voice note shows its length and plays',
        (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia();

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      await sendInboundMedia(
        f,
        kind: MediaKind.voice,
        mime: 'audio/mp4',
        bytes: Uint8List.fromList(List<int>.filled(32, 7)),
        durationMs: 42000,
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(MediaBubble), findsOneWidget);
      expect(find.text('0:42'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      await tester.pump();

      expect(media.players, hasLength(1));
      expect(media.players.single.played, hasLength(1));
      expect(media.players.single.played.single, hasLength(32));
    });

    testWidgets('an inbound photo renders as an image', (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia();

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      await sendInboundMedia(
        f,
        kind: MediaKind.photo,
        mime: 'image/png',
        bytes: _pngBytes,
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(MediaBubble), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Photo unavailable'), findsNothing);
    });

    testWidgets('a media bubble offers no copy, forward or share',
        (tester) async {
      final f = await makeFixture();
      final media = _FakeMedia();

      await tester.pumpWidget(wrap(chat(f, media: media.services)));
      await tester.pump();

      await sendInboundMedia(
        f,
        kind: MediaKind.voice,
        mime: 'audio/mp4',
        bytes: Uint8List.fromList(List<int>.filled(32, 8)),
        durationMs: 1000,
      );
      await tester.pump();
      await tester.pump();

      await tester.longPress(find.byType(MediaBubble));
      await tester.pump();
      await tester.pump();

      expect(find.text('Copy'), findsNothing);
      expect(find.text('Forward'), findsNothing);
      expect(find.text('Share'), findsNothing);
    });
  });
}
