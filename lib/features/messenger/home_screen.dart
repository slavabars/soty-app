import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/i18n/app_prefs.dart';
import '../../core/i18n/soty_l10n.dart';
import '../../core/update/update_controller.dart';
import '../update/update_banner.dart';
import 'chats_tab.dart';
import 'messenger_controller.dart';
import 'peers_tab.dart';
import 'search_screen.dart';
import 'unread_badge.dart';

/// Root chat UI: a "Chats" tab (conversations) and a "Peers" tab (contacts
/// with online/offline status), both hosted by the single Soty app bar.
class HomeScreen extends StatefulWidget {
  final MessengerController messenger;
  final AppPrefs prefs;
  final GlobalKey<ChatsTabState>? chatsTabKey;
  final VoidCallback onIdentity;
  final VoidCallback onSettings;

  /// Handles a tapped `soty://` link inside a message body.
  final Future<void> Function(String route)? onSotyLink;

  /// Drives the startup "new version" banner; `null` hides it entirely.
  final UpdateController? update;

  const HomeScreen({
    super.key,
    required this.messenger,
    required this.prefs,
    this.chatsTabKey,
    required this.onIdentity,
    required this.onSettings,
    this.onSotyLink,
    this.update,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final GlobalKey _fabKey = GlobalKey();
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _sub = widget.messenger.onChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soty'),
        leading: IconButton(
          tooltip: SotyL10n.tr(context, 'Identity'),
          icon: const Icon(Icons.fingerprint),
          onPressed: widget.onIdentity,
        ),
        actions: [
          IconButton(
            tooltip: SotyL10n.tr(context, 'Search'),
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SearchScreen(
                    messenger: widget.messenger,
                    prefs: widget.prefs,
                    onSotyLink: widget.onSotyLink,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: SotyL10n.tr(context, 'Settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: widget.onSettings,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      SotyL10n.tr(context, 'Chats'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.messenger.unreadTotal > 0) ...[
                    const SizedBox(width: 6),
                    UnreadBadge(count: widget.messenger.unreadTotal),
                  ],
                ],
              ),
            ),
            Tab(text: SotyL10n.tr(context, 'Peers')),
          ],
        ),
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton(
              key: _fabKey,
              tooltip: SotyL10n.tr(context, 'New chat'),
              onPressed: _showFloatingMenu,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          if (widget.update != null) UpdateBanner(controller: widget.update!),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                ChatsTab(
                  key: widget.chatsTabKey,
                  messenger: widget.messenger,
                  prefs: widget.prefs,
                  onSotyLink: widget.onSotyLink,
                ),
                PeersTab(
                  messenger: widget.messenger,
                  prefs: widget.prefs,
                  onSotyLink: widget.onSotyLink,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFloatingMenu() async {
    final overlay =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()
            as RenderBox;
    final fabBox = _fabKey.currentContext?.findRenderObject() as RenderBox?;
    final Rect fabRect;
    if (fabBox != null && fabBox.hasSize) {
      final origin = fabBox.localToGlobal(Offset.zero, ancestor: overlay);
      fabRect = origin & fabBox.size;
    } else {
      fabRect = Rect.fromLTWH(
        overlay.size.width - 72,
        overlay.size.height - 72,
        56,
        56,
      );
    }
    const gap = 10.0;
    const margin = 16.0;
    final right = math.max(margin, overlay.size.width - fabRect.right);
    final bottom = math.max(margin, overlay.size.height - fabRect.top + gap);
    final width = math.min(248.0, overlay.size.width - margin * 2);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.14),
      transitionDuration: const Duration(milliseconds: 190),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return Stack(
          children: [
            Positioned(
              right: right,
              bottom: bottom,
              width: width,
              child: FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  alignment: Alignment.bottomRight,
                  scale: Tween<double>(begin: 0.82, end: 1).animate(curved),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.10),
                      end: Offset.zero,
                    ).animate(curved),
                    child: _FloatingActionMenu(
                      onNewChat: () {
                        Navigator.of(dialogContext).pop();
                        widget.chatsTabKey?.currentState?.openNewChat();
                      },
                      onNewGroup: () {
                        Navigator.of(dialogContext).pop();
                        widget.chatsTabKey?.currentState?.openNewGroup();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (_, __, ___, child) => child,
    );
  }
}

class _FloatingActionMenu extends StatelessWidget {
  const _FloatingActionMenu({
    required this.onNewChat,
    required this.onNewGroup,
  });

  final VoidCallback onNewChat;
  final VoidCallback onNewGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      key: const Key('home-new-menu'),
      color: scheme.surfaceContainerHigh,
      elevation: 12,
      shadowColor: scheme.shadow.withValues(alpha: 0.28),
      surfaceTintColor: scheme.surfaceTint,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FloatingMenuItem(
              key: const Key('home-new-chat'),
              icon: Icons.chat_bubble_outline_rounded,
              label: SotyL10n.tr(context, 'New chat'),
              onTap: onNewChat,
            ),
            _FloatingMenuItem(
              key: const Key('home-new-group'),
              icon: Icons.group_add_outlined,
              label: SotyL10n.tr(context, 'New group'),
              onTap: onNewGroup,
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingMenuItem extends StatelessWidget {
  const _FloatingMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
