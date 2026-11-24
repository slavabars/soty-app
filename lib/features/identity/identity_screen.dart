import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/crypto/hex.dart' show isHexOfLength;
import '../../core/i18n/soty_l10n.dart';
import '../../core/security_limits.dart' show maxDisplayNameLength;
import '../../core/storage/pruned_roots_dao.dart';
import '../../core/transport/transport.dart';
import '../../models/peer.dart';
import '../messenger/messenger_controller.dart';
import 'identity_controller.dart';

/// Identity screen: keypair display + peer exchange.
///
/// The keys are shown as selectable plain text; the scannable QR lives in
/// Settings → "My QR code" / "Scan QR code".
class IdentityScreen extends StatefulWidget {
  final IdentityController identity;
  final MessengerController messenger;
  final List<Transport> transports;

  const IdentityScreen({
    super.key,
    required this.identity,
    required this.messenger,
    required this.transports,
  });

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  String? _edPub;
  String? _xPub;
  String _displayName = '';
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _displayName = widget.identity.displayName;
    });
    _edPub = await widget.identity.edPublicKeyHex();
    _xPub = await widget.identity.xPublicKeyHex();
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _displayName);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(SotyL10n.tr(ctx, 'Display name')),
        content: TextField(
          controller: controller,
          maxLength: maxDisplayNameLength,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(SotyL10n.tr(ctx, 'Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              await widget.identity.setDisplayName(controller.text);
              if (ctx.mounted) Navigator.of(ctx).pop();
              await _load();
            },
            child: Text(SotyL10n.tr(ctx, 'Save')),
          ),
        ],
      ),
    );
  }

  Future<void> _copyInvite() async {
    final invite = await widget.identity.invitePayload();
    if (invite == null || !mounted) return;
    await Clipboard.setData(ClipboardData(text: invite));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SotyL10n.tr(context, 'Invite copied to clipboard')),
        ),
      );
    }
  }

  Future<void> _importInvite() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(SotyL10n.tr(ctx, 'Import invite')),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 3,
          decoration: InputDecoration(
            hintText: SotyL10n.tr(ctx, 'Paste the invite JSON here'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(SotyL10n.tr(ctx, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(SotyL10n.tr(ctx, 'Import')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final imported = await widget.messenger.importInvite(
      controller.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          SotyL10n.tr(
            context,
            imported ? 'Peer imported' : 'Invite rejected',
          ),
        ),
      ),
    );
  }

  Future<void> _addPeer() async {
    final xKeyController = TextEditingController();
    final addrController = TextEditingController();
    final peerIdController = TextEditingController();
    final nameController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(SotyL10n.tr(ctx, 'Add peer')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: xKeyController,
                decoration: InputDecoration(
                  labelText: SotyL10n.tr(
                    ctx,
                    'Peer X25519 public key (hex)',
                  ),
                ),
              ),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: SotyL10n.tr(ctx, 'Name (optional)'),
                ),
                maxLength: maxDisplayNameLength,
              ),
              TextField(
                controller: peerIdController,
                decoration: InputDecoration(
                  labelText: SotyL10n.tr(ctx, 'libp2p peer id (optional)'),
                ),
              ),
              TextField(
                controller: addrController,
                decoration: InputDecoration(
                  labelText: SotyL10n.tr(
                    ctx,
                    'Multiaddr (optional, e.g. /ip4/…/tcp/4001)',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(SotyL10n.tr(ctx, 'Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final key = xKeyController.text.trim();
              if (!isHexOfLength(key, 32)) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      SotyL10n.tr(
                        ctx,
                        'Public key must be 64 hex characters',
                      ),
                    ),
                  ),
                );
                return;
              }
              final addrs = addrController.text.trim().isEmpty
                  ? const <String>[]
                  : [addrController.text.trim()];
              final peerId = peerIdController.text.trim().isEmpty
                  ? null
                  : peerIdController.text.trim();
              final imported = await widget.messenger.importPeer(
                DtmPeer(
                  pubKey: key,
                  displayName: nameController.text.trim(),
                  peerId: peerId,
                  addrs: addrs,
                  lastSeen: DateTime.now(),
                ),
              );
              if (imported && ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(SotyL10n.tr(ctx, 'Add')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(SotyL10n.tr(context, 'Identity'))),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(
                    _displayName.isEmpty
                        ? SotyL10n.tr(context, 'Unnamed')
                        : _displayName,
                  ),
                  subtitle: Text(SotyL10n.tr(context, 'Display name')),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: _rename,
                  ),
                ),
                const Divider(),
                _KeyCard(
                  title: SotyL10n.tr(context, 'Ed25519 (identity / signing)'),
                  value: _edPub ?? '',
                  onCopy: () => _copy(_edPub),
                ),
                const SizedBox(height: 12),
                _KeyCard(
                  title: SotyL10n.tr(context, 'X25519 (address peers send to)'),
                  value: _xPub ?? '',
                  onCopy: () => _copy(_xPub),
                ),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.qr_code_2_outlined),
                    title: Text(SotyL10n.tr(context, 'Copy invite')),
                    subtitle: Text(
                      SotyL10n.tr(
                        context,
                        'Signed identity claim — paste it to import your key.',
                      ),
                    ),
                    onTap: _copyInvite,
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.group_add_outlined),
                    title: Text(SotyL10n.tr(context, 'Import invite')),
                    subtitle: Text(
                      SotyL10n.tr(
                        context,
                        'Paste a friend’s signed invite to add them.',
                      ),
                    ),
                    onTap: _importInvite,
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: Text(SotyL10n.tr(context, 'Add a peer')),
                    subtitle: Text(
                      SotyL10n.tr(
                        context,
                        'Paste their X25519 key (+ optional libp2p address) '
                        'to start a conversation.',
                      ),
                    ),
                    onTap: _addPeer,
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(SotyL10n.tr(context, 'Pruning')),
                    subtitle: Text(
                      SotyL10n.tr(context, 'Retention & integrity roots.'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PruningScreen(
                            prunedRootsDao: widget.messenger.prunedRootsDao,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _copy(String? value) async {
    if (value == null || value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
        content: Text(SotyL10n.tr(context, 'Public key copied')),
      ));
    }
  }
}

/// Card that shows one cryptographic public key with a copy affordance.
class _KeyCard extends StatelessWidget {
  final String title;
  final String value;
  final Future<void> Function() onCopy;

  const _KeyCard({
    required this.title,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: onCopy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lists the signed Merkle roots kept after pruning (integrity proofs).
class PruningScreen extends StatefulWidget {
  final PrunedRootsDao prunedRootsDao;

  const PruningScreen({super.key, required this.prunedRootsDao});

  @override
  State<PruningScreen> createState() => _PruningScreenState();
}

class _PruningScreenState extends State<PruningScreen> {
  List<PrunedRootEntry> _roots = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final roots = await widget.prunedRootsDao.getPrunedRoots();
    if (mounted) {
      setState(() {
        _roots = roots;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(SotyL10n.tr(context, 'Pruning integrity roots')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _roots.isEmpty
          ? Center(child: Text(SotyL10n.tr(context, 'No batches pruned yet.')))
          : ListView.builder(
              itemCount: _roots.length,
              itemBuilder: (ctx, i) {
                final root = _roots[i];
                return ListTile(
                  title: Text(
                    SotyL10n.tr(ctx, 'Cutoff {ts}', {
                      'ts': DateTime.fromMillisecondsSinceEpoch(
                        root.cutoffTs,
                      ).toString(),
                    }),
                  ),
                  subtitle: Text(
                    SotyL10n.tr(ctx, 'count: {n}\n{root}', {
                      'n': '${root.count}',
                      'root': root.merkleRoot,
                    }),
                  ),
                  trailing: const Icon(Icons.verified_outlined),
                );
              },
            ),
    );
  }
}
