import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hands an external web link to the platform browser. Deliberately not
/// `url_launcher`: the app reaches the platform through its own channels (see
/// `ShareService`), keeping the dependency set small for a messenger whose
/// core works offline.
///
/// Only `http`/`https` are ever actionable. The scheme is checked here and
/// again on the platform side, so a crafted message can never make the app
/// launch an arbitrary (or internal) intent.
class UrlOpener {
  UrlOpener._();

  static const MethodChannel _channel = MethodChannel('ru.dcns.soty/url');

  /// True only for a well-formed `http`/`https` URL — the same guard the
  /// platform applies before `startActivity`.
  static bool isOpenable(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  /// Opens [url] in the system browser. Returns false when the scheme is not
  /// web, the platform has no handler, or the call fails, so the caller can
  /// fall back to copying the link.
  static Future<bool> open(String url) async {
    if (!isOpenable(url)) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final opened = await _channel.invokeMethod<bool>(
        'openUrl',
        <String, Object?>{'url': url},
      );
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }
}
