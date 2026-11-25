import 'package:flutter/material.dart';

import '../../core/i18n/soty_l10n.dart';

/// Shown instead of the app when the identity seeds cannot be decrypted.
///
/// The usual cause is a system backup restore: Android brings back the
/// encrypted seed blob, but the Android Keystore key that opens it never
/// leaves the original device. There is no way to decrypt the history, so the
/// only honest choices are to restore a Soty backup or start over.
class IdentityRecoveryScreen extends StatelessWidget {
  const IdentityRecoveryScreen({
    super.key,
    required this.onRetry,
    required this.onStartOver,
  });

  final VoidCallback onRetry;
  final Future<void> Function() onStartOver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.key_off_outlined,
                    size: 56,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    SotyL10n.tr(context, 'Keys cannot be read'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    SotyL10n.tr(
                      context,
                      'This usually happens when app data was restored from a '
                      'system backup: the backup holds the encrypted keys, but '
                      'the device key that decrypts them stayed on the old '
                      'phone. Messages cannot be decrypted without it.',
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => _confirmStartOver(context),
                    child: Text(SotyL10n.tr(context, 'Start over')),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onRetry,
                    child: Text(SotyL10n.tr(context, 'Try again')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmStartOver(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(SotyL10n.tr(dialogContext, 'Delete local data')),
        content: Text(
          SotyL10n.tr(
            dialogContext,
            'Start over deletes the local database and media on this device. '
            'If you have a Soty backup file, restore it in Settings after the '
            'app starts.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(SotyL10n.tr(dialogContext, 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(SotyL10n.tr(dialogContext, 'Start over')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await onStartOver();
    }
  }
}
