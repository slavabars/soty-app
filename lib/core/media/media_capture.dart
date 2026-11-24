import 'dart:typed_data';

import '../security_limits.dart'
    show mediaImageMimeTypes, mediaVideoMimeTypes;

/// A photo the user picked, already read into memory.
class PickedPhoto {
  final Uint8List bytes;
  final String mime;

  const PickedPhoto({required this.bytes, required this.mime});
}

/// A video the user picked. [path] points at the platform file so a large
/// video is streamed instead of read into memory; test fakes may supply
/// [bytes] instead.
class PickedVideo {
  final Uint8List bytes;
  final String mime;
  final String? path;
  final int size;

  PickedVideo({
    Uint8List? bytes,
    required this.mime,
    this.path,
    int? size,
  })  : bytes = bytes ?? Uint8List(0),
        size = size ?? bytes?.length ?? 0;

  bool get hasFile => path != null && path!.isNotEmpty;
}

/// What a playback is doing right now.
enum PlaybackState { idle, playing, finished }

/// Records a voice note.
///
/// The composer talks to this interface and never to the plugin, so the
/// widget tests can drive a recording without a microphone.
abstract class VoiceRecorder {
  /// Asks for the microphone permission; `false` when it was denied.
  Future<bool> ensurePermission();

  /// Starts recording; `false` when the recorder refused.
  Future<bool> start();

  /// Stops the recording and returns the captured audio, or `null` when
  /// nothing usable was captured.
  Future<Uint8List?> stop();

  /// Throws the recording away.
  Future<void> cancel();
}

/// Plays a recorded voice note.
abstract class VoicePlayer {
  /// Plays [bytes]; a second call replaces the current playback.
  Future<void> play(Uint8List bytes, {required String mimeType});

  /// Stops the playback.
  Future<void> stop();

  /// Releases the platform resources.
  Future<void> dispose();

  /// The playback state, so a bubble can show a stop button.
  Stream<PlaybackState> get states;
}

/// An arbitrary file the user picked. A real picker returns a [path] so even
/// a multi-gigabyte file is streamed; test fakes may supply [bytes].
class PickedFile {
  final Uint8List bytes;
  final String mime;
  final String? path;
  final int size;

  PickedFile({
    Uint8List? bytes,
    required this.mime,
    this.path,
    int? size,
  })  : bytes = bytes ?? Uint8List(0),
        size = size ?? bytes?.length ?? 0;

  bool get hasFile => path != null && path!.isNotEmpty;
}

/// Picks a photo from the gallery or the camera.
abstract class PhotoPicker {
  /// The picked photo, or `null` when the user cancelled.
  Future<PickedPhoto?> pick({bool camera = false});
}

/// Picks a video from the gallery or the camera.
abstract class VideoPicker {
  /// The picked video, or `null` when the user cancelled.
  Future<PickedVideo?> pick({bool camera = false});
}

/// Picks an arbitrary file from the device.
abstract class FilePicker {
  /// The picked file, or `null` when the user cancelled.
  Future<PickedFile?> pick();
}

/// The platform services the chat screen needs for media. Injected so the
/// widget tests can drive the composer without platform channels.
class MediaServices {
  final VoiceRecorder recorder;
  final PhotoPicker picker;
  final VideoPicker? videoPicker;
  final FilePicker? filePicker;
  final VoicePlayer Function() newPlayer;

  const MediaServices({
    required this.recorder,
    required this.picker,
    this.videoPicker,
    this.filePicker,
    required this.newPlayer,
  });
}

/// The MIME type of an image, sniffed from its magic bytes.
///
/// The file name a picker hands over is not evidence, the bytes are: a
/// hostile or merely odd file must not be able to claim a type the app
/// accepts. `null` when the bytes are not an image type the app takes.
String? detectImageMime(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}

/// Whether [mime] is one a photo container accepts.
bool isAcceptedPhotoMime(String mime) => mediaImageMimeTypes.contains(mime);

/// The MIME type of a video, sniffed from its magic bytes. `null` when the
/// bytes are not a video container the app accepts: the extension a picker
/// reports is not evidence.
String? detectVideoMime(Uint8List bytes) {
  if (bytes.length >= 12 &&
      bytes[4] == 0x66 && // f
      bytes[5] == 0x74 && // t
      bytes[6] == 0x79 && // y
      bytes[7] == 0x70) {
    // p
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (brand == 'qt  ') return 'video/quicktime';
    return 'video/mp4';
  }
  if (bytes.length >= 4 &&
      bytes[0] == 0x1A &&
      bytes[1] == 0x45 &&
      bytes[2] == 0xDF &&
      bytes[3] == 0xA3) {
    return 'video/webm';
  }
  return null;
}

/// Whether [mime] is one a video container accepts.
bool isAcceptedVideoMime(String mime) => mediaVideoMimeTypes.contains(mime);
