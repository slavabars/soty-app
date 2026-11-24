import 'package:dtm_app/core/util/linkify.dart';
import 'package:flutter_test/flutter_test.dart';

/// The runs must always rebuild the original message character for character.
void expectReassembles(List<LinkSpan> spans, String original) {
  expect(spans.map((s) => s.text).join(), original);
}

void main() {
  group('linkify', () {
    test('plain text stays one non-link run', () {
      final spans = linkify('привет, как дела?');
      expect(spans, hasLength(1));
      expect(spans.single.isLink, isFalse);
      expectReassembles(spans, 'привет, как дела?');
    });

    test('empty text yields no runs', () {
      expect(linkify(''), isEmpty);
    });

    test('an https url becomes a link', () {
      final spans = linkify('see https://example.com/path?a=1&b=2');
      expect(spans, hasLength(2));
      expect(spans[0].text, 'see ');
      expect(spans[1].isLink, isTrue);
      expect(spans[1].text, 'https://example.com/path?a=1&b=2');
      expect(spans[1].url, 'https://example.com/path?a=1&b=2');
      expectReassembles(spans, 'see https://example.com/path?a=1&b=2');
    });

    test('an http url keeps its scheme', () {
      final spans = linkify('http://example.org');
      expect(spans.single.url, 'http://example.org');
    });

    test('a bare www host is served over https', () {
      final spans = linkify('go to www.example.com now');
      expect(spans, hasLength(3));
      expect(spans[1].text, 'www.example.com');
      expect(spans[1].url, 'https://www.example.com');
      expectReassembles(spans, 'go to www.example.com now');
    });

    test('trailing sentence punctuation stays out of the link', () {
      final spans = linkify('look at https://example.com.');
      expect(spans, hasLength(3));
      expect(spans[1].text, 'https://example.com');
      expect(spans[1].url, 'https://example.com');
      expect(spans[2].text, '.');
      expectReassembles(spans, 'look at https://example.com.');
    });

    test('a balanced closing paren stays in the link', () {
      const url = 'https://en.wikipedia.org/wiki/Foo_(bar)';
      final spans = linkify('ref $url end');
      expect(spans[1].text, url);
      expect(spans[1].url, url);
    });

    test('an unmatched closing paren is left out of the link', () {
      final spans = linkify('(see https://example.com)');
      expect(spans[1].text, 'https://example.com');
      expectReassembles(spans, '(see https://example.com)');
    });

    test('several links across a message', () {
      final spans = linkify('a https://a.com b http://b.org/c c www.d.net');
      final links = spans.where((s) => s.isLink).toList();
      expect(links.map((s) => s.url), [
        'https://a.com',
        'http://b.org/c',
        'https://www.d.net',
      ]);
      expectReassembles(spans, 'a https://a.com b http://b.org/c c www.d.net');
    });

    test('a non-web scheme is never a link', () {
      for (final text in const [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'data:text/html;base64,AAAA',
        'intent://scan#Intent;scheme=zxing;end',
        'tel:+71234567890',
        'mailto:a@b.c',
      ]) {
        final spans = linkify(text);
        expect(spans.where((s) => s.isLink), isEmpty, reason: text);
        expectReassembles(spans, text);
      }
    });

    test('a soty invite link is tappable', () {
      const link = 'soty://invite?claim=eyJhIjoxfQ';
      final spans = linkify('join $link now');
      expect(spans, hasLength(3));
      expect(spans[1].isLink, isTrue);
      expect(spans[1].text, link);
      expect(spans[1].url, link);
      expectReassembles(spans, 'join $link now');
    });

    test('a soty host link is tappable', () {
      const link = 'soty://host?addr=wss%3A%2F%2Fprice.dcns.ru%2Fsoty-ws';
      final spans = linkify(link);
      expect(spans.single.isLink, isTrue);
      expect(spans.single.url, link);
    });

    test('only the invite and host soty targets are links', () {
      for (final text in const [
        'soty://settings',
        'soty://invite',
        'soty://host',
        'soty://host?addr=',
        'soty://invite?other=1',
        'soty://',
        'soty://evil?claim=x',
      ]) {
        expect(linkify(text).where((s) => s.isLink), isEmpty, reason: text);
        expectReassembles(linkify(text), text);
      }
    });

    test('a soty link inside a longer word is not a link', () {
      expect(
        linkify('xsoty://invite?claim=1').where((s) => s.isLink),
        isEmpty,
      );
    });

    test('trailing punctuation stays out of a soty link', () {
      final spans = linkify('см. soty://invite?claim=aaaa.');
      expect(spans[1].text, 'soty://invite?claim=aaaa');
      expect(spans[2].text, '.');
      expectReassembles(spans, 'см. soty://invite?claim=aaaa.');
    });

    test('a scheme with no host is not a link', () {
      for (final text in const ['http://', 'https://', 'www.', 'http:// x']) {
        expect(linkify(text).where((s) => s.isLink), isEmpty, reason: text);
      }
    });

    test('a host without a dot is not a link', () {
      expect(linkify('http://localhost').where((s) => s.isLink), isEmpty);
    });

    test('www inside a word is not a link', () {
      expect(linkify('notwww.example.com').where((s) => s.isLink), isEmpty);
    });

    test('cyrillic prose after a space stays plain', () {
      final spans = linkify('https://example.com и всё');
      expect(spans[0].text, 'https://example.com');
      expect(spans[1].text, ' и всё');
    });

    test('an em dash terminates the link', () {
      final spans = linkify('https://example.com—это сайт');
      expect(spans[0].text, 'https://example.com');
      expect(spans[0].url, 'https://example.com');
      expectReassembles(spans, 'https://example.com—это сайт');
    });

    test('the number of links is bounded', () {
      final text = List.filled(70, 'https://x.com').join(' ');
      final links = linkify(text, maxLinks: 3).where((s) => s.isLink);
      expect(links, hasLength(3));
    });

    test('an over-long url is left as plain text', () {
      final long = 'https://example.com/${'a' * 3000}';
      final spans = linkify(long, maxUrlLength: 2048);
      expect(spans.where((s) => s.isLink), isEmpty);
    });

    test('huge input is handled without throwing', () {
      final text = '${'a' * 200000} https://example.com ${'b' * 200000}';
      final spans = linkify(text);
      expect(spans.where((s) => s.isLink), hasLength(1));
      expectReassembles(spans, text);
    });

    test('runs always rebuild the source', () {
      for (final text in const [
        '',
        'no links here',
        'http://a.io, https://b.io; (https://c.io)',
        'www.x.y/z?q=1',
        'смотри https://ru.example.org/путь и точка.',
      ]) {
        expectReassembles(linkify(text), text);
      }
    });
  });
}
