import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/i18n/soty_l10n.dart';
import '../../core/invite_link.dart';
import '../identity/identity_controller.dart';

/// Renders this device's signed invite as a QR code others scan to add it.
class MyQrScreen extends StatefulWidget {
  final IdentityController identity;

  const MyQrScreen({super.key, required this.identity});

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  String? _invite;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final invite = await widget.identity.invitePayload();
    if (mounted) {
      setState(() {
        _invite = invite;
        _loading = false;
      });
    }
  }

  Future<void> _copy() async {
    final invite = _invite;
    if (invite == null) return;
    await Clipboard.setData(ClipboardData(text: invite));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SotyL10n.tr(context, 'Invite copied to clipboard')),
        ),
      );
    }
  }

  Future<void> _copyLink() async {
    final invite = _invite;
    if (invite == null) return;
    await Clipboard.setData(ClipboardData(text: InviteLink.encode(invite)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            SotyL10n.tr(context, 'Invite link copied to clipboard'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(SotyL10n.tr(context, 'My QR code')),
        actions: [
          IconButton(
            tooltip: SotyL10n.tr(context, 'Copy invite link'),
            icon: const Icon(Icons.link),
            onPressed: () => unawaited(_copyLink()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invite == null
          ? Center(child: Text(SotyL10n.tr(context, 'No identity yet.')))
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.identity.displayName.isEmpty
                          ? SotyL10n.tr(context, 'Unnamed')
                          : widget.identity.displayName,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      SotyL10n.tr(
                        context,
                        'Others add you by scanning this code from Settings → '
                        'Scan QR code.',
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: QrImageView(
                          data: _invite!,
                          version: QrVersions.auto,
                          size: 280,
                          gapless: true,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy),
                      label: Text(SotyL10n.tr(context, 'Copy invite text')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}