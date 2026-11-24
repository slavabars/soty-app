import 'package:flutter/material.dart';

import '../../core/i18n/soty_l10n.dart';
import '../../core/security_limits.dart';

/// Asks for the backup password and returns it, or `null` on cancel.
///
/// [confirm] shows a second field: a backup that cannot be opened is useless,
/// so the export path never accepts a single typo-prone entry.
Future<String?> showBackupPasswordDialog(
  BuildContext context, {
  required bool confirm,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _BackupPasswordDialog(confirm: confirm),
  );
}

/// Asks before a restore replaces the identity on this device.
Future<bool> showRestoreConfirmation(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(SotyL10n.tr(ctx, 'Restore this backup?')),
      content: Text(
        SotyL10n.tr(
          ctx,
          'This replaces your identity, contacts and messages and restarts '
          'Soty.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(SotyL10n.tr(ctx, 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(SotyL10n.tr(ctx, 'Restore')),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _BackupPasswordDialog extends StatefulWidget {
  final bool confirm;

  const _BackupPasswordDialog({required this.confirm});

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _repeat = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _password.text;
    if (password.length < minBackupPasswordLength) {
      setState(() {
        _error = SotyL10n.tr(
          context,
          'Password must be at least {n} characters',
          {'n': '$minBackupPasswordLength'},
        );
      });
      return;
    }
    if (widget.confirm && password != _repeat.text) {
      setState(() {
        _error = SotyL10n.tr(context, 'Passwords do not match');
      });
      return;
    }
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(SotyL10n.tr(context, 'Backup password')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: SotyL10n.tr(context, 'Backup password'),
            ),
            onSubmitted: widget.confirm ? null : (_) => _submit(),
          ),
          if (widget.confirm) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _repeat,
              obscureText: true,
              decoration: InputDecoration(
                labelText: SotyL10n.tr(context, 'Repeat password'),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(SotyL10n.tr(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: widget.confirm
              ? Text(SotyL10n.tr(context, 'Export'))
              : Text(SotyL10n.tr(context, 'Restore')),
        ),
      ],
    );
  }
}
