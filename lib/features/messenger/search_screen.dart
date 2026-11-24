import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/i18n/app_prefs.dart';
import '../../core/i18n/soty_l10n.dart';
import '../../core/search/message_search.dart';
import '../../models/message_payload.dart' show MediaKind;
import 'chat_screen.dart';
import 'messenger_controller.dart';

/// Searches decrypted message history, globally or inside one chat.
///
/// Results come from [MessengerController.searchMessages], whose index lives
/// in memory only: nothing here reads or writes plaintext on disk.
class SearchScreen extends StatefulWidget {
  final MessengerController messenger;
  final AppPrefs prefs;
  final Future<void> Function(String route)? onSotyLink;

  /// When set, only this chat is searched and results open it.
  final String? conversationId;

  const SearchScreen({
    super.key,
    required this.messenger,
    required this.prefs,
    this.onSotyLink,
    this.conversationId,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  int _generation = 0;
  SearchKind _kind = SearchKind.all;
  bool _unreadOnly = false;
  bool _loading = false;
  List<SearchEntry> _results = const [];

  bool get _scoped => widget.conversationId != null;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_run(value)),
    );
  }

  void _setKind(SearchKind kind) {
    setState(() => _kind = kind);
    unawaited(_run(_query.text));
  }

  void _setUnread(bool value) {
    setState(() => _unreadOnly = value);
    unawaited(_run(_query.text));
  }

  Future<void> _run(String value) async {
    final generation = ++_generation;
    final hasFilter = _kind != SearchKind.all || _unreadOnly;
    if (value.trim().isEmpty && !hasFilter) {
      if (mounted) {
        setState(() {
          _results = const [];
          _loading = false;
        });
      }
      return;
    }
    setState(() => _loading = true);
    final results = await widget.messenger.searchMessages(
      MessageSearch(
        text: value,
        conversationId: widget.conversationId,
        kind: _kind,
        unreadOnly: _unreadOnly,
      ),
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  void _openChat(SearchEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          conversationId: entry.conversationId,
          messenger: widget.messenger,
          prefs: widget.prefs,
          onSotyLink: widget.onSotyLink,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFilter = _kind != SearchKind.all || _unreadOnly;
    final showHint = _query.text.trim().isEmpty && !hasFilter;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onQueryChanged,
          onSubmitted: (value) => unawaited(_run(value)),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: _scoped
                ? SotyL10n.tr(context, 'Search in this chat')
                : SotyL10n.tr(context, 'Search messages'),
          ),
        ),
        actions: [
          if (_query.text.isNotEmpty)
            IconButton(
              tooltip: SotyL10n.tr(context, 'Search'),
              icon: const Icon(Icons.clear),
              onPressed: () {
                _query.clear();
                unawaited(_run(''));
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: Text(SotyL10n.tr(context, 'All')),
                  selected: _kind == SearchKind.all,
                  onSelected: (_) => _setKind(SearchKind.all),
                ),
                ChoiceChip(
                  label: Text(SotyL10n.tr(context, 'Photos')),
                  selected: _kind == SearchKind.photos,
                  onSelected: (_) => _setKind(SearchKind.photos),
                ),
                ChoiceChip(
                  label: Text(SotyL10n.tr(context, 'Voice')),
                  selected: _kind == SearchKind.voice,
                  onSelected: (_) => _setKind(SearchKind.voice),
                ),
                FilterChip(
                  label: Text(SotyL10n.tr(context, 'Unread')),
                  selected: _unreadOnly,
                  onSelected: _setUnread,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : showHint
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            SotyL10n.tr(
                              context,
                              'Type to search your messages.',
                            ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              SotyL10n.tr(context, 'No messages found'),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final entry = _results[index];
                              return ListTile(
                                leading: Icon(_iconFor(entry)),
                                title: Text(
                                  entry.conversationTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  _bodyFor(context, entry),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(
                                  _timeLabel(entry.timestamp),
                                  style: theme.textTheme.labelSmall,
                                ),
                                onTap: () => _openChat(entry),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(SearchEntry entry) => switch (entry.media) {
        MediaKind.photo => Icons.image_outlined,
        MediaKind.voice => Icons.mic_none,
        MediaKind.video => Icons.videocam_outlined,
        MediaKind.file => Icons.insert_drive_file_outlined,
        null => Icons.chat_bubble_outline,
      };

  static String _bodyFor(BuildContext context, SearchEntry entry) {
    return switch (entry.media) {
      MediaKind.photo => SotyL10n.tr(context, 'Photo'),
      MediaKind.voice => SotyL10n.tr(context, 'Voice message'),
      MediaKind.video => SotyL10n.tr(context, 'Video'),
      MediaKind.file => SotyL10n.tr(context, 'File'),
      null => entry.body,
    };
  }

  static String _timeLabel(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
    final now = DateTime.now();
    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    if (sameDay) return '$hh:$mm';
    final dd = date.day.toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');
    return '$dd.$mo';
  }
}
