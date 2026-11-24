import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/crypto/safety_number.dart';
import '../../core/i18n/soty_l10n.dart';
import '../../core/links.dart';
import '../../models/peer.dart';
import 'messenger_controller.dart';
import 'safety_scan_screen.dart';

/// Contact security: the safety number for one 1:1 peer, its QR form, and the
/// verified/mismatch state of the peer's Ed25519 binding.
///
/// The number mixes both parties' Ed25519 and X25519 keys, so a relay or host
/// that swaps a key changes the code on both sides. Verification is a local
/// record only: it never leaves the device and is never claimed with a message.
class PeerSecurityScreen extends StatefulWidget {
  final MessengerController messenger;
  final String peerPubKey;

  /// Test seam: opens the abuse report in a browser. The default launches the
  /// system browser; a widget test injects a recorder.
  final Future<bool> Function(Uri uri)? opener;

  const PeerSecurityScreen({
    super.key,
    required this.messenger,
    required this.peerPubKey,
    this.opener,
  });

  @override
  State<PeerSecurityScreen> createState() => _PeerSecurityScreenState();
}

class _PeerSecurityScreenState extends State<PeerSecurityScreen> {
  String? _code;
  String? _codeFor;
  bool _busy = false;
  StreamSubscription<void>? _changes;

  DtmPeer? get _peer => widget.messenger.peers[widget.peerPubKey];

  @override
  void initState() {
    super.initState();
    _changes = widget.messenger.onChange.listen((_) {
      final ed = _peer?.edPubKey;
      if (ed != null && ed != _codeFor) _compute();
      if (mounted) setState(() {});
    });
    _compute();
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  Future<void> _compute() async {
    final peer = _peer;
    final ed = peer?.edPubKey;
    if (peer == null || ed == null || ed.isEmpty) {
      setState(() {
        _code = null;
        _codeFor = null;
      });
      return;
    }
    try {
      final code = await SafetyNumber.forPair(
        myX: widget.messenger.myXPubKey,
        myEd: widget.messenger.myEdPubKey,
        theirX: peer.pubKey,
        theirEd: ed,
      );
      if (!mounted) return;
      setState(() {
        _code = code;
        _codeFor = ed;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _code = null;
        _codeFor = ed;
      });
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final ok = await widget.messenger.markPeerVerified(widget.peerPubKey);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            SotyL10n.tr(context, 'Could not verify this contact'),
          ),
        ),
      );
    }
  }

  Future<void> _scan() async {
    final code = _code;
    if (code == null) return;
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SafetyScanScreen()),
    );
    if (scanned == null || !mounted) return;
    final matches = SafetyNumber.matches(code, scanned);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          SotyL10n.tr(
            context,
            matches ? 'Safety codes match' : 'Safety codes do not match',
          ),
        ),
      ),
    );
  }

  Future<void> _copy() async {
    final code = _code;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(SotyL10n.tr(context, 'Copied'))),
    );
  }

  Future<void> _setBlocked(bool blocked) async {
    setState(() => _busy = true);
    try {
      await widget.messenger.setPeerBlocked(widget.peerPubKey, blocked);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report() async {
    final uri = abuseReportUri(
      languageCode: Localizations.localeOf(context).languageCode,
      peerKey: widget.peerPubKey,
    );
    final opener = widget.opener ?? _openExternal;
    var opened = false;
    try {
      opened = await opener(uri);
    } catch (_) {
      opened = false;
    }
    if (opened || !mounted) return;
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(SotyL10n.tr(context, 'Link copied'))),
    );
  }

  static Future<bool> _openExternal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peer = _peer;
    final code = _code;
    final name = peer?.displayName.isNotEmpty == true
        ? peer!.displayName
        : SotyL10n.tr(context, 'Unnamed');
    return Scaffold(
      appBar: AppBar(title: Text(SotyL10n.tr(context, 'Safety number'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          _StatusChip(peer: peer),
          const SizedBox(height: 16),
          if (peer?.keyChanged == true) ...[
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SotyL10n.tr(context, 'Security code changed'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      SotyL10n.tr(
                        context,
                        '{name} presented a new key. Compare the new code '
                        'before trusting this chat.',
                        {'name': name},
                      ),
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (code != null) ...[
            Text(
              SotyL10n.tr(
                context,
                'Compare this code with {name} in person or over a trusted '
                'channel.',
                {'name': name},
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 1.2,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: QrImageView(
                    data: 'soty:safety:${SafetyNumber.digitsOnly(code)}',
                    version: QrVersions.auto,
                    size: 220,
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
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(SotyL10n.tr(context, 'Copy code')),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(SotyL10n.tr(context, 'Scan their code')),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy || peer?.isVerified == true ? null : _verify,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(SotyL10n.tr(context, 'Mark as verified')),
            ),
          ] else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SotyL10n.tr(context, 'Safety code unavailable'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      SotyL10n.tr(
                        context,
                        'This contact has not published an Ed25519 key yet.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.block),
              title: Text(SotyL10n.tr(context, 'Block contact')),
              subtitle: Text(
                SotyL10n.tr(
                  context,
                  'Messages from this contact are ignored and never decrypted.',
                ),
              ),
              value: widget.messenger.isPeerBlocked(widget.peerPubKey),
              onChanged: _busy
                  ? null
                  : (value) => unawaited(_setBlocked(value)),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(SotyL10n.tr(context, 'Report abuse')),
              subtitle: Text(
                SotyL10n.tr(
                  context,
                  'Opens the report form on soty.su in a browser',
                ),
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => unawaited(_report()),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final DtmPeer? peer;

  const _StatusChip({required this.peer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = peer;
    if (p != null && p.isVerified) {
      return _row(
        Icons.verified_user,
        Colors.green,
        SotyL10n.tr(context, 'Verified'),
      );
    }
    if (p != null && p.keyChanged) {
      return _row(
        Icons.warning_amber_rounded,
        theme.colorScheme.error,
        SotyL10n.tr(context, 'Security code changed'),
      );
    }
    return _row(
      Icons.help_outline,
      theme.colorScheme.onSurfaceVariant,
      SotyL10n.tr(context, 'Not verified'),
    );
  }

  Widget _row(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
