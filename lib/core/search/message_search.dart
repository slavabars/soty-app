import '../../models/message_payload.dart' show MediaKind;
import '../security_limits.dart' show maxSearchResults;

/// What the user is looking for.
enum SearchKind {
  /// Any message; the text query still applies.
  all,
  photos,
  voice,
}

/// One searchable message, already decrypted and detached from storage.
class SearchEntry {
  final String id;
  final String conversationId;
  final String conversationTitle;
  final String body;
  final int timestamp;
  final bool outgoing;
  final bool unread;
  final MediaKind? media;

  const SearchEntry({
    required this.id,
    required this.conversationId,
    required this.conversationTitle,
    required this.body,
    required this.timestamp,
    required this.outgoing,
    required this.unread,
    this.media,
  });
}

/// One query: free text plus the filters the search screen shows.
class MessageSearch {
  final String text;
  final String? conversationId;
  final SearchKind kind;
  final bool unreadOnly;

  const MessageSearch({
    required this.text,
    this.conversationId,
    this.kind = SearchKind.all,
    this.unreadOnly = false,
  });
}

/// Filters and sorts [entries]; newest first, capped at [maxSearchResults].
///
/// Matching is case-insensitive substring search over the decrypted body and
/// the chat title. An empty query is only useful together with a filter: with
/// no text and no filter there is nothing to show, so the result is empty.
List<SearchEntry> runSearch(
  List<SearchEntry> entries,
  MessageSearch query,
) {
  final needle = query.text.trim().toLowerCase();
  final hasFilter = query.kind != SearchKind.all || query.unreadOnly;
  if (needle.isEmpty && !hasFilter) return const [];

  final out = <SearchEntry>[];
  for (final entry in entries) {
    if (query.conversationId != null &&
        entry.conversationId != query.conversationId) {
      continue;
    }
    if (query.unreadOnly && !entry.unread) continue;
    switch (query.kind) {
      case SearchKind.photos:
        if (entry.media != MediaKind.photo) continue;
      case SearchKind.voice:
        if (entry.media != MediaKind.voice) continue;
      case SearchKind.all:
        break;
    }
    if (needle.isNotEmpty &&
        !entry.body.toLowerCase().contains(needle) &&
        !entry.conversationTitle.toLowerCase().contains(needle)) {
      continue;
    }
    out.add(entry);
  }
  out.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  if (out.length > maxSearchResults) {
    return out.sublist(0, maxSearchResults);
  }
  return out;
}
