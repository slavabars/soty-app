import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/crypto/hex.dart' show isHexOfLength;
import '../../core/i18n/soty_l10n.dart';
import '../../core/storage/conversation_dao.dart' show ConversationDao;
import 'messenger_controller.dart';

/// Members and roles of one group. Admins can add/remove members, promote and
/// demote; everyone else sees the roster read-only.
class GroupInfoScreen extends StatefulWidget {
  final MessengerController messenger;
  final String conversationId;

  const GroupInfoScreen({
    super.key,
    required this.messenger,
    required this.conversationId,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  List<({String key, String role})> _members = const [];
  String _title = '';
  bool _admin = false;
  bool _loading = true;
  StreamSubscription<void>? _changes;

  @override
  void initState() {
    super.initState();
    _changes = widget.messenger.onChange.listen((_) => unawaited(_load()));
    unawaited(_load());
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final members = await widget.messenger.groupMembers(
      widget.conversationId,
    );
    final admin = await widget.messenger.isGroupAdmin(
      widget.conversationId,
    );
    if (!mounted) return;
    setState(() {
      _members = members;
      _admin = admin;
      _title = widget.messenger.chatTitle(widget.conversationId);
      _loading = false;
    });
  }

  String _name(String key) {
    if (key == widget.messenger.myXPubKey) {
      return SotyL10n.tr(context, 'You');
    }
    final name = widget.messenger.senderNameFor(key);
    return name.isEmpty ? key : name;
  }

  Future<void> _addMember() async {
    final controller = TextEditingController();
    final key = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(SotyL10n.tr(ctx, 'Add member')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: SotyL10n.tr(ctx, 'Peer X25519 public key (hex)'),
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
            child: Text(SotyL10n.tr(ctx, 'Add member')),
          ),
        ],
      ),
    );
    // The dialog's closing animation still builds the field for a few frames,
    // so the controller is left to the GC instead of being disposed under it.
    if (key == null || !mounted) return;
    if (!isHexOfLength(key, 32)) {
      _snack(SotyL10n.tr(context, 'Could not update the group.'));
      return;
    }
    final ok = await widget.messenger.addGroupMember(
      widget.conversationId,
      key,
    );
    if (!mounted) return;
    if (!ok) {
      _snack(SotyL10n.tr(context, 'Could not update the group.'));
    }
  }

  Future<void> _setRole(String key, bool admin) async {
    final ok = await widget.messenger.setGroupMemberRole(
      widget.conversationId,
      key,
      admin ? ConversationDao.adminRole : ConversationDao.memberRole,
    );
    if (!mounted || ok) return;
    _snack(SotyL10n.tr(context, 'Could not update the group.'));
  }

  Future<void> _remove(String key) async {
    final ok = await widget.messenger.removeGroupMember(
      widget.conversationId,
      key,
    );
    if (!mounted || ok) return;
    _snack(SotyL10n.tr(context, 'Could not update the group.'));
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(SotyL10n.tr(context, 'Group info'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(_title, style: theme.textTheme.headlineSmall),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${SotyL10n.tr(context, 'Members')}: ${_members.length}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 8),
                for (final member in _members)
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(_name(member.key)),
                    subtitle: Text(
                      member.role == ConversationDao.adminRole
                          ? SotyL10n.tr(context, 'Admin')
                          : SotyL10n.tr(context, 'Member'),
                    ),
                    trailing: _admin && member.key != widget.messenger.myXPubKey
                        ? PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'promote':
                                  unawaited(_setRole(member.key, true));
                                case 'demote':
                                  unawaited(_setRole(member.key, false));
                                case 'remove':
                                  unawaited(_remove(member.key));
                              }
                            },
                            itemBuilder: (ctx) => [
                              if (member.role != ConversationDao.adminRole)
                                PopupMenuItem(
                                  value: 'promote',
                                  child: Text(
                                    SotyL10n.tr(ctx, 'Make admin'),
                                  ),
                                )
                              else
                                PopupMenuItem(
                                  value: 'demote',
                                  child: Text(
                                    SotyL10n.tr(ctx, 'Remove admin'),
                                  ),
                                ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text(
                                  SotyL10n.tr(ctx, 'Remove member'),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                if (_admin)
                  ListTile(
                    leading: const Icon(Icons.person_add_alt),
                    title: Text(SotyL10n.tr(context, 'Add member')),
                    onTap: () => unawaited(_addMember()),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      SotyL10n.tr(
                        context,
                        'Only admins can change this group.',
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
    );
  }
}
