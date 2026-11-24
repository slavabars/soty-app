import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What happened when the app asked the platform to hand an APK to the
/// installer.
enum InstallLaunch {
  /// The package-installer activity was started; the user finishes there.
  started,

  /// This app is not allowed to install packages yet and the platform's
  /// "install unknown apps" screen was opened instead.
  needsPermission,

  /// No platform channel (desktop, tests) or the installer activity failed.
  unavailable,
}

/// The hand-off to the platform's package installer.
abstract interface class UpdateInstaller {
  /// Whether the platform will let this app start an install intent.
  Future<bool> canInstall();

  /// Hands [path] to the package installer, or opens the unknown-sources
  /// screen when that is still forbidden.
  Future<InstallLaunch> install(String path);

  /// SHA-256 of the signer certificate: of [path] when given, otherwise of
  /// the installed app. `null` when the platform cannot tell (desktop, tests).
  Future<String?> signerSha256(String? path);
}

/// Android implementation over the `ru.dcns.soty/update` channel. The platform
/// side re-validates the path and only ever exposes this app's own cache
/// directory through a FileProvider.
class PlatformUpdateInstaller implements UpdateInstaller {
  const PlatformUpdateInstaller({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'ru.dcns.soty/update';
  final MethodChannel _channel;

  @override
  Future<bool> canInstall() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final allowed = await _channel.invokeMethod<bool>('canInstall');
      return allowed ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<String?> signerSha256(String? path) async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _channel.invokeMethod<String>('certificate', {
        'path': path,
      });
    } catch (_) {
      // Best effort: a missing binding or an unreadable APK must never turn a
      // normal update into a failure by itself.
      return null;
    }
  }

  @override
  Future<InstallLaunch> install(String path) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return InstallLaunch.unavailable;
    }
    try {
      final result = await _channel.invokeMethod<String>('install', {
        'path': path,
      });
      return switch (result) {
        'started' => InstallLaunch.started,
        'needsPermission' => InstallLaunch.needsPermission,
        _ => InstallLaunch.unavailable,
      };
    } on PlatformException {
      return InstallLaunch.unavailable;
    } on MissingPluginException {
      return InstallLaunch.unavailable;
    }
  }
}
