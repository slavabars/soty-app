import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/i18n/soty_l10n.dart';
import 'app_lock_controller.dart';

/// Full-screen gate shown whenever the app lock is enabled and has not been
/// unlocked in this session. Unlocks via password (always) or biometrics
/// (when enabled and the device supports it).
class LockScreen extends StatefulWidget {
  final AppLockController appLock;
  final VoidCallback onUnlocked;

  const LockScreen({
    super.key,
    required this.appLock,
    required this.onUnlocked,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  bool _error = false;
  bool? _biometricAvailable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_checkBiometrics());
    });
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final appLock = widget.appLock;
    if (!appLock.isBiometricEnabled) return;
    final supported = await appLock.biometricAuth.isSupported();
    if (!mounted) return;
    setState(() => _biometricAvailable = supported);
    if (supported) {
      unawaited(_unlockWithBiometric());
    }
  }

  Future<void> _unlockWithBiometric() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await widget.appLock.unlockWithBiometric(
      reason: SotyL10n.tr(context, 'Unlock Soty'),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onUnlocked();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final password = _password.text;
    if (password.isEmpty) return;
    setState(() {
      _busy = true;
      _error = false;
    });
    final ok = await widget.appLock.verify(password);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = !ok;
    });
    if (ok) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    SotyL10n.tr(context, 'Soty is locked'),
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    SotyL10n.tr(context, 'Enter your password to continue.'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _password,
                    autofocus: true,
                    obscureText: true,
                    enabled: !_busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: (_) => unawaited(_submit()),
                    decoration: InputDecoration(
                      labelText: SotyL10n.tr(context, 'Password'),
                      border: const OutlineInputBorder(),
                      errorText: _error
                          ? SotyL10n.tr(context, 'Incorrect password')
                          : null,
                      suffixIcon:
                          widget.appLock.isBiometricEnabled &&
                              _biometricAvailable == true
                          ? IconButton(
                              tooltip: SotyL10n.tr(
                                context,
                                'Unlock with fingerprint',
                              ),
                              icon: const Icon(Icons.fingerprint),
                              onPressed: _busy
                                  ? null
                                  : () => unawaited(_unlockWithBiometric()),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : () => unawaited(_submit()),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(SotyL10n.tr(context, 'Unlock')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}