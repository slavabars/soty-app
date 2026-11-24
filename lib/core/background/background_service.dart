import 'package:flutter/services.dart';

/// Starts and stops the Android foreground service that keeps the mesh radios
/// and the relay connections alive while the app is not on screen.
///
/// Deliberately best-effort: on hosts without the channel (desktop during
/// tests, unsupported builds) every call is a silent no-op, so nothing in the
/// app has to branch on the platform before talking to a background service.
class BackgroundService {
  static const MethodChannel _channel =
      MethodChannel('ru.dcns.soty/background_service');

  Future<void> start() => _invoke('start');

  Future<void> stop() => _invoke('stop');

  /// Whether the system lets the app run without battery optimization; false
  /// when the platform cannot answer (e.g. desktop tests).
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the user-initiated "no restrictions" dialog. No-op off Android and
  /// when the platform refuses (some OEM builds), which Settings surfaces as
  /// a sticky "Restricted by the system" row.
  Future<void> requestIgnoreBatteryOptimizations() =>
      _invoke('requestIgnoreBatteryOptimizations');

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Off Android there is no service to talk to.
    } on PlatformException {
      // The service is optional; its failure must not break the app.
    }
  }
}