import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/i18n/soty_l10n.dart';
import '../../core/net/url_opener.dart';
import '../../core/util/linkify.dart';

/// Renders message text with any `http(s)`/`www.` URL tappable. Tapping opens
/// the link in the browser; when the platform cannot open it the URL is copied
/// instead, so a tap is never a dead end.
///
/// Our own `soty://invite` / `soty://host` links are never handed to the
/// browser: when [onSotyLink] is set they go through the same in-app deep-link
/// handling a platform launch uses, otherwise they are ignored.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText(
    this.text, {
    super.key,
    this.style,
    this.onOpen,
    this.onSotyLink,
  });

  final String text;
  final TextStyle? style;

  /// Overrides the default "open in browser" action, used by tests.
  final Future<void> Function(String url)? onOpen;

  /// Handles a tapped `soty://` link. Receives the raw link as its route.
  /// When null, a `soty://` tap does nothing (no browser, no copy).
  final Future<void> Function(String route)? onSotyLink;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  /// One recognizer per link, created lazily and reused across rebuilds so a
  /// theme change never leaks one. Disposed with the widget.
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _recognizer(int index, String url) {
    while (_recognizers.length <= index) {
      _recognizers.add(TapGestureRecognizer());
    }
    return _recognizers[index]..onTap = () => _open(url);
  }

  Future<void> _open(String url) async {
    if (url.toLowerCase().startsWith('soty://')) {
      final route = widget.onSotyLink;
      if (route != null) await route(url);
      return;
    }
    final handler = widget.onOpen;
    if (handler != null) {
      await handler(url);
      return;
    }
    if (await UrlOpener.open(url)) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(SotyL10n.tr(context, 'Link copied to clipboard')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spans = linkify(widget.text);
    // Link-free text (the common case) stays a plain `Text` so callers and
    // tests that read `Text.data` keep working, and no span tree is allocated.
    if (!spans.any((span) => span.isLink)) {
      return Text(widget.text, style: widget.style);
    }
    final linkColor = Theme.of(context).colorScheme.primary;
    final linkStyle = TextStyle(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );
    final children = <InlineSpan>[];
    var index = 0;
    for (final span in spans) {
      final url = span.url;
      children.add(
        url == null
            ? TextSpan(text: span.text)
            : TextSpan(
                text: span.text,
                style: linkStyle,
                recognizer: _recognizer(index++, url),
              ),
      );
    }
    return Text.rich(
      TextSpan(
        style: widget.style ?? DefaultTextStyle.of(context).style,
        children: children,
      ),
    );
  }
}
