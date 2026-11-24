import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/crypto/hex.dart' show isHexOfLength;
import '../../core/crypto/identity_claim.dart';
import '../../core/i18n/app_prefs.dart';
import '../../core/i18n/soty_l10n.dart';
import '../../models/conversation.dart';
import '../../models/peer.dart';
import 'chat_screen.dart';
import 'messenger_controller.dart';
import 'peer_name_dialog.dart';
import 'peer_presence.dart';
import 'unread_badge.dart';

/// Conversations tab: one tile per chat, newest activity first. A 1:1 chat
/// materializes once it has messages and is title-renameable independently
/// of the contact's display name.
class ChatsTab extends StatefulWidget {
  final MessengerController messenger;
  final AppPrefs prefs;

  /// Handles a tapped `soty://` link inside a chat opened from this tab.
  final Future<void> Function(String route)? onSotyLink;

  const ChatsTab({
    super.key,
    required this.messenger,
    required this.prefs,
    this.onSotyLink,
  });

  @override
  State<ChatsTab> createState() => ChatsTabState();
}

class ChatsTabState extends State<ChatsTab> with AutomaticKeepAliveClientMixin {
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

  /// Surfaces a verified invite link: opens the existing conversation when
  /// that peer is already known, otherwise imports the peer with everything
  /// the signed claim carries (routing key, identity binding, display name)
  /// and opens the new chat immediately.
  Future<void> openInvite(IdentityClaim claim) async {
    final known =
        widget.messenger.peers[claim.xPubKey] ??
        widget.messenger.peerByEdPubKey(claim.edPubKey);
    if (known != null && known.edPubKey == claim.edPubKey) {
      _openChat(known.pubKey);
      return;
    }
    final imported = await widget.messenger.importPeer(
      DtmPeer(
        pubKey: claim.xPubKey,
        edPubKey: claim.edPubKey,
        displayName: claim.displayName,
        lastSeen: DateTime.now(),
      ),
    );
    if (!mounted) return;
    if (imported) {
      _openChat(claim.xPubKey);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SotyL10n.tr(context, 'Invalid public key'))),
      );
    }
  }

  /// FAB action: manually add a peer (X key + optional name/routing) and open
  /// the chat, exactly like the invite path but typed in by hand.
  Future<void> openNewChat() async {
    final keyController = TextEditingController();
    final nameController = TextEditingController();
    final addrController = TextEditingController();
    final peerIdController = TextEditingController();

    final peer = await showDialog<DtmPeer>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(SotyL10n.tr(ctx, 'New chat')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyController,
                decoration: InputDecoration(
                  labelText: SotyL10n.tr(
                    ctx,
                    'Peer X25519 public key (hex) *',
                  ),
                ),
              ),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: SotyL10n.tr(ctx, 'Name (optional)'),
                ),
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
                  labelText: SotyL10n.tr(ctx, 'Multiaddr (optional)'),
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
            onPressed: () {
              final key = keyController.text.trim();
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
              Navigator.of(ctx).pop(
                DtmPeer(
                  pubKey: key,
                  displayName: nameController.text.trim(),
                  peerId: peerIdController.text.trim().isEmpty
                      ? null
                      : peerIdController.text.trim(),
                  addrs: addrController.text.trim().isEmpty
                      ? const <String>[]
                      : [addrController.text.trim()],
                  lastSeen: DateTime.now(),
                ),
              );
            },
            child: Text(SotyL10n.tr(ctx, 'Start')),
          ),
        ],
      ),
    );

    if (peer == null) return;
    final imported = await widget.messenger.importPeer(peer);
    debugPrint('Soty new chat imported=$imported key=$peer');
    if (!mounted) return;
    if (imported) {
      _openChat(peer.pubKey);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SotyL10n.tr(context, 'Invalid public key'))),
      );
    }
  }

  /// FAB action: pick a name and the contact members for a new group, then
  /// open it. Only the local conversation is created in v1 (roster
  /// distribution is a later phase).
  Future<void> openNewGroup() async {
    final nameController = TextEditingController();
    final selected = <String, bool>{};
    final contacts = widget.messenger.contacts;

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(SotyL10n.tr(ctx, 'New group')),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: SotyL10n.tr(ctx, 'Group name'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (contacts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(SotyL10n.tr(ctx, 'Add peers first.')),
                    )
                  else
                    ...contacts.map(
                      (peer) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          peer.displayName.isNotEmpty
                              ? peer.displayName
                              : _shorten(peer.pubKey),
                        ),
                        value: selected[peer.pubKey] ?? false,
                        onChanged: (value) => setDialogState(
                          () => selected[peer.pubKey] = value ?? false,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(SotyL10n.tr(ctx, 'Cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(nameController.text.trim()),
              child: Text(SotyL10n.tr(ctx, 'Create')),
            ),
          ],
        ),
      ),
    );
    if (name == null || !mounted) return;

    final members = [
      for (final peer in contacts)
        if (selected[peer.pubKey] ?? false) peer.pubKey,
    ];
    final conversationId = await widget.messenger.createGroup(
      title: name,
      memberPeerKeys: members,
      ts: DateTime.now().millisecondsSinceEpoch,
    );
    if (!mounted) return;
    _openChat(conversationId);
  }

  void _openChat(String conversationId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          messenger: widget.messenger,
          prefs: widget.prefs,
          onSotyLink: widget.onSotyLink,
        ),
      ),
    );
  }

  Future<void> _renameChat(String conversationId) async {
    final name = await showPeerNameDialog(
      context,
      title: SotyL10n.tr(context, 'Rename chat'),
      initial: widget.messenger.chatTitle(conversationId),
    );
    if (name != null && mounted) {
      await widget.messenger.renameConversation(conversationId, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final conversations = widget.messenger.conversationList;
    if (conversations.isEmpty) {
      return Center(
        child: Text(
          SotyL10n.tr(context, 'No conversations yet.\nAdd a peer to start.'),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: conversations.length,
      itemBuilder: (ctx, i) {
        final conversation = conversations[i];
        final presence = presenceOf(
          widget.messenger.peers[conversation.id],
        );
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: conversation.isGroup
                ? Theme.of(context).colorScheme.secondaryContainer
                : switch (presence) {
                    PeerPresence.online => Colors.green,
                    PeerPresence.recent => Colors.orange,
                    PeerPresence.offline => Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                  },
            child: Icon(
              conversation.isGroup
                  ? Icons.groups
                  : presence == PeerPresence.online
                  ? Icons.wifi
                  : Icons.wifi_off,
              color: conversation.isGroup ||
                      presence == PeerPresence.online
                  ? Colors.white
                  : null,
              size: 18,
            ),
          ),
          title: Text(widget.messenger.chatTitle(conversation.id)),
          subtitle: Text(_subtitle(conversation)),
          trailing: UnreadBadge.maybe(conversation.unreadCount),
          onTap: () => _openChat(conversation.id),
          onLongPress: () => _renameChat(conversation.id),
        );
      },
    );
  }

  String _subtitle(ConversationView conversation) {
    if (!conversation.isGroup) return _shorten(conversation.id);
    return SotyL10n.tr(
      context,
      'Members: {n}',
      {'n': '${conversation.memberKeys.length}'},
    );
  }

  static String _shorten(String key) => key.length <= 16
      ? key
      : '${key.substring(0, 8)}…${key.substring(key.length - 6)}';
}