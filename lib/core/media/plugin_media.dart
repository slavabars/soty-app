import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:image_picker/image_picker.dart' as picker;
import 'package:mime/mime.dart' show lookupMimeType;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as rec;

import 'media_capture.dart';

/// The recorder backed by the `record` plugin.
///
/// The bit rate is deliberately low: a voice note travels in one envelope and
/// the media blob is capped at 128 KiB, so 24 kbit/s mono leaves room for the
/// full 30 seconds without tripping the cap.
class PluginVoiceRecorder implements VoiceRecorder {
  static const rec.RecordConfig _config = rec.RecordConfig(
    encoder: rec.AudioEncoder.aacLc,
    bitRate: 24000,
    sampleRate: 22050,
    numChannels: 1,
  );

  rec.AudioRecorder? _recorder;

  rec.AudioRecorder get _instance => _recorder ??= rec.AudioRecorder();

  @override
  Future<bool> ensurePermission() async {
    try {
      return await _instance.hasPermission();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> start() async {
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.start(_config, path: '${dir.path}/soty_voice_$stamp.m4a');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Uint8List?> stop() async {
    String? path;
    try {
      path = await _instance.stop();
    } catch (_) {
      return null;
    }
    if (path == null) return null;
    return _readAndDelete(path);
  }

  @override
  Future<void> cancel() async {
    try {
      await _instance.cancel();
    } catch (_) {
      // A cancelled recording is gone either way.
    }
  }

  static Future<Uint8List?> _readAndDelete(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      await _delete(file);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _delete(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // A leftover file in the cache directory is harmless.
    }
  }
}

/// The picker backed by the `image_picker` plugin.
///
/// The plugin is asked for a bounded rendition, so an ordinary gallery photo
/// lands inside the media blob cap instead of being refused outright.
class PluginPhotoPicker implements PhotoPicker {
  static const double _maxEdge = 900;
  static const int _quality = 70;

  picker.ImagePicker? _picker;

  picker.ImagePicker get _instance => _picker ??= picker.ImagePicker();

  @override
  Future<PickedPhoto?> pick({bool camera = false}) async {
    try {
      final image = await _instance.pickImage(
        source: camera ? picker.ImageSource.camera : picker.ImageSource.gallery,
        maxWidth: _maxEdge,
        maxHeight: _maxEdge,
        imageQuality: _quality,
      );
      if (image == null) return null;
      final bytes = await image.readAsBytes();
      return PickedPhoto(bytes: bytes, mime: detectImageMime(bytes) ?? '');
    } catch (_) {
      return null;
    }
  }
}

/// Picks a video from the gallery. The bytes are sniffed for their container
/// type so a file renamed to `.mp4` cannot claim a video type it is not.
class PluginVideoPicker implements VideoPicker {
  picker.ImagePicker? _picker;

  picker.ImagePicker get _instance => _picker ??= picker.ImagePicker();

  @override
  Future<PickedVideo?> pick({bool camera = false}) async {
    try {
      final video = await _instance.pickVideo(
        source: camera ? picker.ImageSource.camera : picker.ImageSource.gallery,
      );
      if (video == null) return null;
      final file = File(video.path);
      final size = await file.length();
      final raf = await file.open();
      late final Uint8List head;
      try {
        head = await raf.read(512);
      } finally {
        await raf.close();
      }
      final mime = detectVideoMime(head);
      if (mime == null) return null;
      return PickedVideo(bytes: Uint8List(0), mime: mime,
          path: video.path, size: size);
    } catch (_) {
      return null;
    }
  }
}

/// The player backed by the `audioplayers` plugin.
///
/// The bytes are written to a temporary file with the extension their MIME
/// type implies: the Android media stack picks its decoder from the file
/// name, and a bare byte array leaves it guessing.
class PluginVoicePlayer implements VoicePlayer {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _subscription;
  File? _scratch;
  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();

  AudioPlayer _instance() {
    final existing = _player;
    if (existing != null) return existing;
    final created = AudioPlayer();
    _player = created;
    _subscription = created.onPlayerStateChanged.listen((state) {
      if (_states.isClosed) return;
      _states.add(
        switch (state) {
          PlayerState.playing => PlaybackState.playing,
          PlayerState.completed => PlaybackState.finished,
          _ => PlaybackState.idle,
        },
      );
    });
    return created;
  }

  @override
  Future<void> play(Uint8List bytes, {required String mimeType}) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/soty_voice_play${_extensionFor(mimeType)}',
    );
    await file.writeAsBytes(bytes, flush: true);
    await _removeScratch();
    _scratch = file;
    await _instance().play(DeviceFileSource(file.path));
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _player?.dispose();
    _player = null;
    await _removeScratch();
    await _states.close();
  }

  @override
  Stream<PlaybackState> get states => _states.stream;

  Future<void> _removeScratch() async {
    final file = _scratch;
    _scratch = null;
    if (file == null) return;
    try {
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // A leftover file in the cache directory is harmless.
    }
  }

  /// The file extension a media stack expects for [mimeType].
  static String _extensionFor(String mimeType) => switch (mimeType) {
        'audio/mpeg' => '.mp3',
        'audio/ogg' => '.ogg',
        'audio/webm' => '.webm',
        'audio/wav' => '.wav',
        'audio/x-wav' => '.wav',
        'audio/aac' => '.aac',
        'audio/amr' => '.amr',
        'audio/3gpp' => '.3gp',
        _ => '.m4a',
      };
}


/// Picks any file with the platform document picker. The MIME comes from the
/// picker when it knows it, otherwise from the file name; an unknown type is
/// `application/octet-stream`, which the `file` container accepts.
class PluginFilePicker implements FilePicker {
  @override
  Future<PickedFile?> pick() async {
    try {
      final selected = await fs.openFile();
      if (selected == null) return null;
      final file = File(selected.path);
      final size = await file.length();
      final mime = selected.mimeType ??
          lookupMimeType(selected.name) ??
          'application/octet-stream';
      return PickedFile(bytes: Uint8List(0), mime: mime,
          path: selected.path, size: size);
    } catch (_) {
      return null;
    }
  }
}
