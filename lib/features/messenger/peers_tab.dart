import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/i18n/app_prefs.dart';
import '../../core/i18n/soty_l10n.dart';
import '../../models/peer.dart';
import 'chat_screen.dart';
import 'messenger_controller.dart';
import 'peer_name_dialog.dart';
import 'peer_presence.dart';

/// Contacts tab: every imported/discovered peer with online/offline status.
/// Tap opens the 1:1 chat; long press renames the *contact* (not the chat).
class PeersTab extends StatefulWidget {
  final MessengerController messenger;
  final AppPrefs prefs;

  /// Handles a tapped `soty://` link inside a chat opened from this tab.
  final Future<void> Function(String route)? onSotyLink;

  const PeersTab({
    super.key,
    required this.messenger,
    required this.prefs,
    this.onSotyLink,
  });

  @override
  State<PeersTab> createState() => _PeersTabState();
}

class _PeersTabState extends State<PeersTab>
    with AutomaticKeepAliveClientMixin {
  StreamSubscription<void>? _sub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _sub = widget.messenger.onChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  List<DtmPeer> get _sorted {
    final peers = widget.messenger.contacts;
    final now = DateTime.now();
    peers.sort((a, b) {
      final rankA = presenceOf(a, now: now).index;
      final rankB = presenceOf(b, now: now).index;
      if (rankA != rankB) return rankA.compareTo(rankB);
      final byName = a.displayName
          .toLowerCase()
          .compareTo(b.displayName.toLowerCase());
      if (byName != 0) return byName;
      return a.pubKey.compareTo(b.pubKey);
    });
    return peers;
  }

  void _openChat(String peerPubKey) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          conversationId: peerPubKey,
          messenger: widget.messenger,
          prefs: widget.prefs,
          onSotyLink: widget.onSotyLink,
        ),
      ),
    );
  }

  Future<void> _renameContact(String peerPubKey) async {
    final peer = widget.messenger.peers[peerPubKey];
    final name = await showPeerNameDialog(
      context,
      title: SotyL10n.tr(context, 'Rename contact'),
      initial: peer?.displayName.isNotEmpty == true
          ? peer!.displayName
          : _shorten(peerPubKey),
    );
    if (name != null && mounted) {
      await widget.messenger.renamePeer(peerPubKey, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final peers = _sorted;
    if (peers.isEmpty) {
      return Center(
        child: Text(
          SotyL10n.tr(context, 'No contacts yet.\nImport an invite to start.'),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: peers.length,
      itemBuilder: (ctx, i) {
        final peer = peers[i];
        final title = peer.displayName.isNotEmpty
            ? peer.displayName
            : _shorten(peer.pubKey);
        final presence = presenceOf(peer);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: switch (presence) {
              PeerPresence.online => Colors.green,
              PeerPresence.recent => Colors.orange,
              PeerPresence.offline =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
            },
            child: Icon(
              presence == PeerPresence.online ? Icons.wifi : Icons.wifi_off,
              color: presence == PeerPresence.online ? Colors.white : null,
              size: 18,
            ),
          ),
          title: Text(title),
          subtitle: Text(
            '${_shorten(peer.pubKey)} · ${presenceLabel(context, peer)}',
          ),
          onTap: () => _openChat(peer.pubKey),
          onLongPress: () => _renameContact(peer.pubKey),
        );
      },
    );
  }

  static String _shorten(String key) => key.length <= 16
      ? key
      : '${key.substring(0, 8)}…${key.substring(key.length - 6)}';
}