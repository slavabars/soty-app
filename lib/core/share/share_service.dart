import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Shares plain text via the system share sheet when available, with a
/// platform-aware fallback (clipboard only) for environments that lack it.
class ShareService {
  ShareService._();

  static const MethodChannel _channel =
      MethodChannel('ru.dcns.soty/share');

  /// Shares [text] with the system share chooser. On Android this forwards to
  /// `Intent.ACTION_SEND`. On desktop (Linux/macOS/Windows) the share sheet is
  /// not available in a consistent cross-platform way here, so the text is not
  /// automatically shared via the channel; callers should prefer a clipboard
  /// fallback instead.
  static Future<bool> shareText(String text) async {
    if (text.trim().isEmpty) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await _channel.invokeMethod('shareText', {'text': text});
      return true;
    } catch (_) {
      return false;
    }
  }
}
