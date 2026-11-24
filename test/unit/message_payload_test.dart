import 'package:dtm_app/core/security_limits.dart' show maxReceiptIds;
import 'package:dtm_app/models/group_payload.dart'
    show GroupContainerKind;
import 'package:dtm_app/models/message_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final key = 'a' * 64;
  final key2 = 'b' * 64;
  final conv = 'c' * 64;
  final corr = 'd' * 64;

  group('MessagePayload.parse', () {
    test('plain text is a text payload', () {
      final payload = MessagePayload.parse('hello');
      expect(payload, isA<TextPayload>());
      expect((payload as TextPayload).text, 'hello');
    });

    test('empty plaintext is a text payload', () {
      expect(MessagePayload.parse(''), isA<TextPayload>());
    });

    test('a direct header yields the sender X key and the body', () {
      final payload = MessagePayload.parse('x1 $key\nhi there');
      expect(payload, isA<DirectPayload>());
      final direct = payload as DirectPayload;
      expect(direct.senderX, key);
      expect(direct.text, 'hi there');
    });

    test('a direct body may span newlines', () {
      final direct =
          MessagePayload.parse('x1 $key\nline1\nline2') as DirectPayload;
      expect(direct.text, 'line1\nline2');
    });

    test('a direct header with a bad key falls back to text', () {
      const raw = 'x1 nothex\nhi';
      final payload = MessagePayload.parse(raw);
      expect(payload, isA<TextPayload>());
      expect((payload as TextPayload).text, raw);
    });

    test('a delivered receipt parses its ids', () {
      final payload = MessagePayload.parse('d1\n$key,$key2');
      expect(payload, isA<ReceiptPayload>());
      final receipt = payload as ReceiptPayload;
      expect(receipt.kind, ReceiptKind.delivered);
      expect(receipt.ids, [key, key2]);
    });

    test('a read receipt parses its ids', () {
      final receipt = MessagePayload.parse('r1\n$key2') as ReceiptPayload;
      expect(receipt.kind, ReceiptKind.read);
      expect(receipt.ids, [key2]);
    });

    test('a malformed receipt is control, never a text bubble', () {
      final empty = MessagePayload.parse('d1\n');
      expect(empty, isA<ReceiptPayload>());
      expect((empty as ReceiptPayload).ids, isEmpty);

      final garbage = MessagePayload.parse('r1\nnothex');
      expect(garbage, isA<ReceiptPayload>());
      expect((garbage as ReceiptPayload).ids, isEmpty);
    });

    test('a truncated receipt keeps the ids it did carry', () {
      final payload = MessagePayload.parse('d1\n$key,bad') as ReceiptPayload;
      expect(payload.ids, [key]);
    });

    test('a receipt id list is clamped to the limit', () {
      final ids = List.generate(
        maxReceiptIds + 5,
        (i) => i.toRadixString(16).padLeft(64, '0'),
      );
      final receipt = MessagePayload.parse('d1\n${ids.join(',')}')
          as ReceiptPayload;
      expect(receipt.ids, hasLength(maxReceiptIds));
      expect(receipt.ids.first, ids.first);
    });

    test('a group message carries conversation, correlation and sender', () {
      final payload =
          MessagePayload.parse('g2 $conv $corr $key\nhello team');
      expect(payload, isA<GroupMessagePayload>());
      final group = payload as GroupMessagePayload;
      expect(group.conversationId, conv);
      expect(group.corrId, corr);
      expect(group.senderX, key);
      expect(group.kind, GroupContainerKind.message);
      expect(group.value, 'hello team');
    });

    test('a group title parses', () {
      final title = MessagePayload.parse('t1 $conv $key\nNew name')
          as GroupMessagePayload;
      expect(title.kind, GroupContainerKind.title);
      expect(title.conversationId, conv);
      expect(title.senderX, key);
      expect(title.value, 'New name');
    });

    test('a malformed group header falls back to text', () {
      final raw = 'g2 $conv short $key\nhello';
      expect(MessagePayload.parse(raw), isA<TextPayload>());
    });

    test('legacy g1/m1 containers still parse', () {
      final message = MessagePayload.parse('g1$conv\nhi');
      expect(message, isA<GroupMessagePayload>());
      final group = message as GroupMessagePayload;
      expect(group.conversationId, conv);
      expect(group.corrId, '');
      expect(group.senderX, '');
      expect(group.kind, GroupContainerKind.message);
      expect(group.value, 'hi');

      final title = MessagePayload.parse('m1$conv\nTeam')
          as GroupMessagePayload;
      expect(title.kind, GroupContainerKind.title);
      expect(title.value, 'Team');
    });
  });

  group('compose round-trips through parse', () {
    test('direct', () {
      final raw = MessagePayload.composeDirect(senderX: key, text: 'hi');
      final direct = MessagePayload.parse(raw) as DirectPayload;
      expect(direct.senderX, key);
      expect(direct.text, 'hi');
    });

    test('group message', () {
      final raw = MessagePayload.composeGroupMessage(
        conversationId: conv,
        corrId: corr,
        senderX: key,
        text: 'all hands',
      );
      final group = MessagePayload.parse(raw) as GroupMessagePayload;
      expect(group.conversationId, conv);
      expect(group.corrId, corr);
      expect(group.senderX, key);
      expect(group.value, 'all hands');
    });

    test('group title', () {
      final title = MessagePayload.parse(
        MessagePayload.composeGroupTitle(
          conversationId: conv,
          senderX: key,
          title: 'New name',
        ),
      ) as GroupMessagePayload;
      expect(title.kind, GroupContainerKind.title);
      expect(title.value, 'New name');
    });

    test('receipt', () {
      final payload = MessagePayload.parse(
        MessagePayload.composeReceipt(
          kind: ReceiptKind.read,
          ids: [key, key2],
        ),
      ) as ReceiptPayload;
      expect(payload.kind, ReceiptKind.read);
      expect(payload.ids, [key, key2]);
    });

    test('one receipt frame never exceeds the id cap', () {
      final ids = List.generate(
        maxReceiptIds + 3,
        (i) => '$i'.padLeft(64, '0'),
      );
      final encoded = MessagePayload.composeReceipt(
        kind: ReceiptKind.delivered,
        ids: ids,
      );
      final receipt = MessagePayload.parse(encoded) as ReceiptPayload;
      expect(receipt.ids, hasLength(maxReceiptIds));
    });

    test('composeReceipts splits a long batch, never dropping the tail', () {
      final ids = List.generate(
        maxReceiptIds * 2 + 7,
        (i) => '$i'.padLeft(64, '0'),
      );
      final frames = MessagePayload.composeReceipts(
        kind: ReceiptKind.read,
        ids: ids,
      );
      expect(frames, hasLength(3));
      final acked = <String>[];
      for (final frame in frames) {
        final receipt = MessagePayload.parse(frame) as ReceiptPayload;
        expect(receipt.ids.length, lessThanOrEqualTo(maxReceiptIds));
        acked.addAll(receipt.ids);
      }
      expect(acked, ids);
    });

    test('a batch of only malformed ids produces no receipt frame', () {
      expect(
        MessagePayload.composeReceipts(
          kind: ReceiptKind.delivered,
          ids: const ['', 'zz'],
        ),
        isEmpty,
      );
    });
  });

  group('replies', () {
    final ref = '1' * 64;
    final quoteX = '2' * 64;
    final conv = 'c' * 64;
    final corr = 'd' * 64;

    test('x2 parses a reply with quote and preview', () {
      final payload = MessagePayload.parse(
        'x2 $key $ref $quoteX\nquoted line\nactual body',
      ) as DirectPayload;
      expect(payload.senderX, key);
      expect(payload.text, 'actual body');
      final quote = payload.quote!;
      expect(quote.refId, ref);
      expect(quote.authorX, quoteX);
      expect(quote.preview, 'quoted line');
    });

    test('x2 with missing second newline keeps the text, drops the quote', () {
      final raw = 'x2 $key $ref $quoteX\nquoted only';
      final payload = MessagePayload.parse(raw) as DirectPayload;
      expect(payload.senderX, key);
      expect(payload.text, 'quoted only');
      expect(payload.quote, isNull);
    });

    test('x2 with bad ref id falls back to text', () {
      final raw = 'x2 $key badhex $quoteX\nq\nb';
      expect(MessagePayload.parse(raw), isA<TextPayload>());
    });

    test('x2 with bad quote author falls back to text', () {
      final raw = 'x2 $key $ref nothex\nq\nb';
      expect(MessagePayload.parse(raw), isA<TextPayload>());
    });

    test('g3 parses a group reply', () {
      final payload = MessagePayload.parse(
        'g3 $conv $corr $key $ref $quoteX\npreview\nbody',
      ) as GroupMessagePayload;
      expect(payload.kind, GroupContainerKind.message);
      expect(payload.conversationId, conv);
      expect(payload.corrId, corr);
      expect(payload.senderX, key);
      expect(payload.value, 'body');
      expect(payload.quote?.refId, ref);
      expect(payload.quote?.preview, 'preview');
    });

    test('g3 with wrong part count falls back to text', () {
      final raw = 'g3 $conv $corr $key $ref\np\nb';
      expect(MessagePayload.parse(raw), isA<TextPayload>());
    });

    test('g3 with no preview line stays a group message, quote dropped', () {
      final raw = 'g3 $conv $corr $key $ref $quoteX\nonly one line';
      final payload = MessagePayload.parse(raw) as GroupMessagePayload;
      expect(payload.kind, GroupContainerKind.message);
      expect(payload.conversationId, conv);
      expect(payload.corrId, corr);
      expect(payload.senderX, key);
      expect(payload.value, 'only one line');
      expect(payload.quote, isNull);
    });

    test('composeDirect with quote produces x2 and round-trips', () {
      final raw = MessagePayload.composeDirect(
        senderX: key,
        text: 'reply text',
        quote: QuoteRef(
          refId: ref,
          authorX: quoteX,
          preview: 'quoted',
        ),
      );
      expect(raw.startsWith('x2'), isTrue);
      final parsed = MessagePayload.parse(raw) as DirectPayload;
      expect(parsed.text, 'reply text');
      expect(parsed.quote?.preview, 'quoted');
    });

    test('compose falls back to x1 when quote ids are invalid', () {
      final raw = MessagePayload.composeDirect(
        senderX: key,
        text: 'hi',
        quote: QuoteRef(
          refId: 'bad',
          authorX: quoteX,
          preview: 'q',
        ),
      );
      expect(raw.startsWith('x1'), isTrue);
    });

    test('compose strips newlines from preview and clamps it', () {
      final long = 'a' * 200;
      final raw = MessagePayload.composeGroupMessage(
        conversationId: conv,
        corrId: corr,
        senderX: key,
        text: 'body',
        quote: QuoteRef(
          refId: ref,
          authorX: quoteX,
          preview: 'line1\nline2\r$long',
        ),
      );
      expect(raw.startsWith('g3'), isTrue);
      final parsed = MessagePayload.parse(raw) as GroupMessagePayload;
      expect(parsed.quote?.preview, contains('line1 line2'));
      expect(parsed.quote!.preview.runes.length, 160);
    });
  });
}
