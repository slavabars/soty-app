import 'package:flutter/material.dart';

import '../../core/i18n/soty_l10n.dart';
import '../../core/security_limits.dart' show maxDisplayNameLength;

/// Asks the user for a chat name and returns it, or `null` when cancelled.
Future<String?> showPeerNameDialog(
  BuildContext context, {
  required String title,
  required String initial,
}) async {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        maxLength: maxDisplayNameLength,
        autofocus: true,
        decoration: InputDecoration(
          labelText: SotyL10n.tr(ctx, 'Chat name'),
        ),
        onSubmitted: (value) => Navigator.of(ctx).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(SotyL10n.tr(ctx, 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: Text(SotyL10n.tr(ctx, 'Save')),
        ),
      ],
    ),
  );
}