import 'package:flutter/services.dart';

/// Runtime BLE/Wi-Fi permissions, asked for over the app's own method channel.
///
/// Android 12+ gates scanning, connecting and advertising behind runtime
/// permissions, and the mesh plugin has no way to ask for them: it swallows
/// the resulting [SecurityException], so the offline transport looks started
/// while nothing is discoverable. Requesting them here makes a denial visible
/// instead of silent.
class MeshPermissions {
  final MethodChannel _channel;

  MeshPermissions({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'ru.dcns.soty/mesh_permissions';

  /// Ask for anything not granted yet and report the outcome.
  Future<MeshPermissionStatus> request() async {
    return _read(await _channel.invokeMapMethod<String, Object?>('request'));
  }

  /// What is granted right now, without prompting the user.
  Future<MeshPermissionStatus> status() async {
    return _read(await _channel.invokeMapMethod<String, Object?>('status'));
  }

  MeshPermissionStatus _read(Map<String, Object?>? raw) {
    if (raw == null) {
      // No platform channel: a desktop or test build, where the mesh simply
      // is not available. Not a denial.
      return const MeshPermissionStatus.unsupported();
    }
    final granted = _strings(raw, 'granted');
    final denied = _strings(raw, 'denied');
    final required = _strings(raw, 'required');
    final sdk = raw['sdk'];
    if (sdk is! int) {
      throw FormatException('mesh permissions: sdk must be an int, got $sdk');
    }
    return MeshPermissionStatus(
      sdk: sdk,
      required: required,
      granted: granted,
      denied: denied,
    );
  }

  List<String> _strings(Map<String, Object?> raw, String key) {
    final value = raw[key];
    if (value is! List) {
      throw FormatException(
        'mesh permissions: $key must be a list, got $value',
      );
    }
    return value.map((entry) {
      if (entry is! String) {
        throw FormatException(
          'mesh permissions: $key must hold strings, got $entry',
        );
      }
      return entry;
    }).toList();
  }
}

/// Outcome of a permission check. [unsupported] marks a platform with no
/// method channel at all, which is not a denial.
class MeshPermissionStatus {
  final int sdk;
  final List<String> required;
  final List<String> granted;
  final List<String> denied;
  final bool unsupported;

  const MeshPermissionStatus({
    required this.sdk,
    required this.required,
    required this.granted,
    required this.denied,
    this.unsupported = false,
  });

  const MeshPermissionStatus.unsupported()
    : sdk = 0,
      required = const <String>[],
      granted = const <String>[],
      denied = const <String>[],
      unsupported = true;

  /// True when nothing stands between the mesh and the radio. An unsupported
  /// platform counts as fine: there is no permission to hold there.
  bool get ok => unsupported || denied.isEmpty;

  @override
  String toString() =>
      'MeshPermissionStatus(sdk: $sdk, granted: $granted, denied: $denied)';
}