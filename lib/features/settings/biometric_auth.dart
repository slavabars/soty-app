import 'package:local_auth/local_auth.dart';

import 'app_lock_controller.dart';

/// Biometric prompt backed by the `local_auth` plugin.
class LocalBiometricAuth implements BiometricAuth {
  final LocalAuthentication _local;

  LocalBiometricAuth([LocalAuthentication? local])
    : _local = local ?? LocalAuthentication();

  @override
  Future<bool> isSupported() async {
    try {
      return await _local.isDeviceSupported() &&
          await _local.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _local.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}