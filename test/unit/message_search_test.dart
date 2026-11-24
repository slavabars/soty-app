import 'package:dtm_app/core/search/message_search.dart';
import 'package:dtm_app/models/message_payload.dart';
import 'package:flutter_test/flutter_test.dart';

SearchEntry entry({
  required String id,
  String conversation = 'c1',
  String title = 'Anna',
  String body = '',
  int timestamp = 1000,
  bool outgoing = false,
  bool unread = false,
  MediaKind? media,
}) {
  return SearchEntry(
    id: id,
    conversationId: conversation,
    conversationTitle: title,
    body: body,
    timestamp: timestamp,
    outgoing: outgoing,
    unread: unread,
    media: media,
  );
}

void main() {
  final entries = [
    entry(id: '1', body: 'hello world', timestamp: 100),
    entry(id: '2', body: 'Hello again', timestamp: 200, unread: true),
    entry(id: '3', body: '', media: MediaKind.photo, timestamp: 300),
    entry(id: '4', body: '', media: MediaKind.voice, timestamp: 400),
    entry(
      id: '5',
      conversation: 'c2',
      title: 'Bob',
      body: 'hi from bob',
      timestamp: 500,
    ),
  ];

  test('matches the body case-insensitively, newest first', () {
    final hits = runSearch(entries, const MessageSearch(text: 'HELLO'));
    expect(hits.map((e) => e.id), ['2', '1']);
  });

  test('matches the chat title as well as the body', () {
    final hits = runSearch(entries, const MessageSearch(text: 'bob'));
    expect(hits.map((e) => e.id), ['5']);
  });

  test('a conversation scope excludes other chats', () {
    final hits = runSearch(
      entries,
      const MessageSearch(text: '', conversationId: 'c1', unreadOnly: true),
    );
    expect(hits.map((e) => e.id), ['2']);
  });

  test('the unread filter keeps only unseen messages', () {
    final hits = runSearch(
      entries,
      const MessageSearch(text: 'hello', unreadOnly: true),
    );
    expect(hits.map((e) => e.id), ['2']);
  });

  test('media filters work without text and keep newest first', () {
    expect(
      runSearch(entries, const MessageSearch(text: '', kind: SearchKind.photos))
          .map((e) => e.id),
      ['3'],
    );
    expect(
      runSearch(entries, const MessageSearch(text: '', kind: SearchKind.voice))
          .map((e) => e.id),
      ['4'],
    );
  });

  test('an empty query with no filter returns nothing', () {
    expect(runSearch(entries, const MessageSearch(text: '   ')), isEmpty);
    expect(runSearch(entries, const MessageSearch(text: 'missing')), isEmpty);
  });

  test('results are capped at the shared limit', () {
    final many = [
      for (var i = 0; i < 250; i++)
        entry(id: '$i', body: 'spam', timestamp: i, unread: true),
    ];
    final hits = runSearch(
      many,
      const MessageSearch(text: '', unreadOnly: true),
    );
    expect(hits, hasLength(100));
    expect(hits.first.timestamp, 249);
  });

  test('searching 10 000 indexed messages stays under 100 ms', () {
    final corpus = [
      for (var i = 0; i < 10000; i++)
        entry(
          id: '$i',
          body: 'message number $i ${i % 7 == 0 ? 'urgent' : 'routine'}',
          timestamp: i,
        ),
    ];
    final watch = Stopwatch()..start();
    final hits = runSearch(corpus, const MessageSearch(text: 'urgent'));
    watch.stop();

    expect(hits, isNotEmpty);
    expect(hits.length, lessThanOrEqualTo(100));
    expect(
      watch.elapsedMilliseconds,
      lessThan(100),
      reason: 'budget for a 10k-message index',
    );
  });
}
