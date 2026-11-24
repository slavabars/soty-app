import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/i18n/soty_l10n.dart';
import '../../core/media/media_capture.dart';
import '../../models/message_payload.dart' show MediaKind;
import 'messenger_controller.dart';

/// Renders the media a bubble carries: a photo as an image, a voice note as
/// a play button with its duration.
class MediaBubble extends StatelessWidget {
  final MediaAttachment media;

  /// Builds the player a voice note bubble owns; every bubble disposes its
  /// own, so two bubbles can play at once without fighting over one player.
  final VoicePlayer Function() newPlayer;

  const MediaBubble({
    super.key,
    required this.media,
    required this.newPlayer,
  });

  @override
  Widget build(BuildContext context) {
    if (media.kind == MediaKind.file) return _FileBubble(media: media);
    if (media.isPhoto) return _PhotoBubble(media: media);
    if (media.kind == MediaKind.video) return _VideoBubble(media: media);
    return _VoiceBubble(media: media, newPlayer: newPlayer);
  }
}

/// A photo bubble. The bytes are decoded once: the base64 travels with the
/// message, and decoding it on every rebuild would cost a copy per frame.
class _PhotoBubble extends StatefulWidget {
  final MediaAttachment media;

  const _PhotoBubble({required this.media});

  @override
  State<_PhotoBubble> createState() => _PhotoBubbleState();
}

class _PhotoBubbleState extends State<_PhotoBubble> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _decode(widget.media.dataBase64);
  }

  static Uint8List? _decode(String dataBase64) {
    try {
      return base64Decode(dataBase64);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openPhoto(BuildContext context) async {
    final bytes = _bytes;
    if (bytes == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PhotoViewer(bytes: bytes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return Text(SotyL10n.tr(context, 'Photo unavailable'));
    }
    return GestureDetector(
      onTap: () => _openPhoto(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

/// A voice note bubble: a play button, the length of the take and a stop
/// button while it plays.
class _VoiceBubble extends StatefulWidget {
  final MediaAttachment media;
  final VoicePlayer Function() newPlayer;

  const _VoiceBubble({required this.media, required this.newPlayer});

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  VoicePlayer? _player;
  StreamSubscription<PlaybackState>? _subscription;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    final player = widget.newPlayer();
    _player = player;
    _subscription = player.states.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == PlaybackState.playing);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    final player = _player;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    final player = _player;
    if (player == null) return;
    if (_playing) {
      await player.stop();
      return;
    }
    Uint8List bytes;
    try {
      bytes = base64Decode(widget.media.dataBase64);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SotyL10n.tr(context, 'Voice message failed'))),
        );
      }
      return;
    }
    try {
      await player.play(bytes, mimeType: widget.media.mime);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SotyL10n.tr(context, 'Voice message failed'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = widget.media.duration;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
          tooltip: SotyL10n.tr(
            context,
            _playing ? 'Stop' : 'Play voice message',
          ),
          onPressed: _toggle,
        ),
        const SizedBox(width: 8),
        Text(
          formatMediaDuration(duration),
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.bytes});

  final Uint8List bytes;

  Future<void> _save(BuildContext context) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/soty_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              SotyL10n.tr(
                context,
                'Photo saved to {path}',
                {'path': file.path},
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SotyL10n.tr(context, 'Failed to save photo'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: SotyL10n.tr(context, 'Save'),
            onPressed: () => _save(context),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.memory(bytes),
        ),
      ),
    );
  }
}

/// A media length as `m:ss`, the shape a voice note is usually read in.
String formatMediaDuration(Duration duration) {
  final total = duration.inSeconds;
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// A video bubble with an inline player: the encrypted attachment is written
/// to a private temp file once, then played by `video_player`. The file and
/// controller are disposed with the bubble.
class _VideoBubble extends StatefulWidget {
  final MediaAttachment media;

  const _VideoBubble({required this.media});

  @override
  State<_VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<_VideoBubble> {
  VideoPlayerController? _controller;
  File? _file;
  bool _tempOwned = false;
  bool _failed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final File file;
      if (widget.media.hasFile) {
        file = File(widget.media.filePath);
        _tempOwned = false;
      } else {
        final bytes = base64Decode(widget.media.dataBase64);
        final dir = await getTemporaryDirectory();
        file = File('${dir.path}/soty-video-${widget.media.blobId}.mp4');
        await file.writeAsBytes(bytes, flush: true);
        _tempOwned = true;
      }
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(false);
      setState(() {
        _file = file;
        _controller = controller;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    final file = _file;
    if (file != null && _tempOwned) {
      unawaited(file.delete().catchError((_) => file));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed) {
      return Text(SotyL10n.tr(context, 'Video unavailable'));
    }
    if (controller == null) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final value = controller.value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: GestureDetector(
        onTap: () {
          controller.value.isPlaying ? controller.pause() : controller.play();
          setState(() {});
        },
        child: AspectRatio(
          aspectRatio: value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
              if (!value.isPlaying)
                const Icon(
                  Icons.play_circle_fill,
                  size: 56,
                  color: Colors.white,
                ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Text(
                  _duration(value.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.black45,
                  shape: const CircleBorder(),
                  child: IconButton(
                    iconSize: 18,
                    tooltip: SotyL10n.tr(context, 'Save video'),
                    color: Colors.white,
                    onPressed: _saving ? null : () => unawaited(_save()),
                    icon: const Icon(Icons.download),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Writes the decrypted attachment to the app documents directory so the
  /// video survives the temp cleanup and can be opened from a file manager.
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = switch (widget.media.mime) {
        'video/webm' => 'webm',
        'video/quicktime' => 'mov',
        _ => 'mp4',
      };
      final file = File(
        '${dir.path}/soty_video_${widget.media.blobId.substring(0, 8)}'
        '_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      if (widget.media.hasFile) {
        await File(widget.media.filePath).copy(file.path);
      } else {
        await file.writeAsBytes(
          base64Decode(widget.media.dataBase64),
          flush: true,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            SotyL10n.tr(context, 'Video saved to {path}', {'path': file.path}),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SotyL10n.tr(context, 'Failed to save video'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _duration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}


/// An arbitrary file: never played inline, only saved. The bytes are already
/// in the encrypted attachment; the bubble names the size and offers a save
/// button that writes a copy into the app documents directory.
class _FileBubble extends StatefulWidget {
  final MediaAttachment media;

  const _FileBubble({required this.media});

  @override
  State<_FileBubble> createState() => _FileBubbleState();
}

class _FileBubbleState extends State<_FileBubble> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/soty_file_${widget.media.blobId.substring(0, 8)}'
        '_${DateTime.now().millisecondsSinceEpoch}.'
        '${_extensionForMime(widget.media.mime)}',
      );
      if (widget.media.hasFile) {
        await File(widget.media.filePath).copy(file.path);
      } else {
        await file.writeAsBytes(
          base64Decode(widget.media.dataBase64),
          flush: true,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            SotyL10n.tr(context, 'File saved to {path}', {'path': file.path}),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SotyL10n.tr(context, 'Failed to save file'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mb = (widget.media.byteCount / (1024 * 1024)).toStringAsFixed(1);
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  SotyL10n.tr(context, 'File'),
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  '$mb MB',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: SotyL10n.tr(context, 'Save file'),
            onPressed: _saving ? null : () => unawaited(_save()),
          ),
        ],
      ),
    );
  }
}

/// The extension a saved file gets from its MIME type. A missing or unknown
/// type falls back to `.bin`; the content is never executed by the app.
String _extensionForMime(String mime) {
  switch (mime) {
    case 'application/pdf':
      return 'pdf';
    case 'application/zip':
      return 'zip';
    case 'application/json':
      return 'json';
    case 'text/plain':
      return 'txt';
    case 'audio/mp4':
    case 'audio/mp4a-latm':
      return 'm4a';
    case 'audio/mpeg':
      return 'mp3';
    case 'audio/ogg':
      return 'ogg';
    case 'video/mp4':
      return 'mp4';
    case 'video/webm':
      return 'webm';
    case 'video/quicktime':
      return 'mov';
    case 'image/jpeg':
      return 'jpg';
    case 'image/png':
      return 'png';
    case 'image/webp':
      return 'webp';
  }
  final slash = mime.indexOf('/');
  if (slash > 0 && slash < mime.length - 1) {
    final tail = mime.substring(slash + 1).split('+').first;
    if (RegExp(r'^[a-z0-9]{1,8}$').hasMatch(tail)) return tail;
  }
  return 'bin';
}
