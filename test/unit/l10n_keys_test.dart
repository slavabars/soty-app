import 'dart:io';

import 'package:dtm_app/core/i18n/soty_l10n.dart';
import 'package:dtm_app/core/update/update_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keys that reach [SotyL10n] through a variable instead of a literal. Every
/// entry is a deliberate decision: a new dynamic key source makes this test
/// fail until it is reviewed, so a string can never reach the UI with no
/// translation at all.
const Set<String> _dynamicKeySources = {
  'identity_screen.dart:imported ? \'Peer imported\' : \'Invite rejected\'',
  'chat_screen.dart:i == 0 ? \'Recent\' : emojiCategories[i - 1].label',
  'chat_screen.dart:message',
  'chat_screen.dart:label',
  'chat_screen.dart:_label(status)',
  'media_bubble.dart:_playing ? \'Stop\' : \'Play voice message\'',
  'peer_security_screen.dart:matches ? \'Safety codes match\' : '
      '\'Safety codes do not match\'',
  'settings_screen.dart:update.phase == UpdatePhase.failed ? '
      '\'Could not check for updates\' : \'You have the latest version\'',
  'settings_screen.dart:added ? \'Relay host added\' : '
      '\'Relay host list is full (max {max})\'',
  'settings_screen.dart:confirmLabel',
  'settings_screen.dart:_themeName(option)',
  'settings_screen.dart:key',
  'update_banner.dart:controller.failureKey ?? \'Download failed\'',
  'update_banner.dart:controller.readyToInstall ? \'Install\' : \'Download\'',
  'main.dart:message',
  'main.dart:appLockResetNotice',
  'main.dart:kind == MediaKind.voice ? \'Voice message\' : '
      'kind == MediaKind.video ? \'Video\' : '
      'kind == MediaKind.file ? \'File\' : \'Photo\'',
};

/// User-visible strings that live in a `const` rather than a call site.
const List<String> _constantKeys = [
  appLockResetNotice,
  UpdateController.checksumMismatchNotice,
  UpdateController.signatureChangedNotice,
];

/// One key found in the source, plus where it came from.
typedef _Found = ({String source, String? key, String? dynamic});

void main() {
  test('every user-facing key is translated in every non-English locale', () {
    final found = _scan();
    expect(found, isNotEmpty, reason: 'the scanner found no call sites');
    expect(
      found.length,
      greaterThan(100),
      reason: 'the scanner should see every SotyL10n call site',
    );

    final dynamicSources = <String>{};
    final keys = <String>{..._constantKeys};
    for (final entry in found) {
      final key = entry.key;
      if (key != null) {
        keys.add(key);
      } else {
        dynamicSources.add(entry.dynamic!);
      }
    }

    expect(
      dynamicSources,
      _dynamicKeySources,
      reason: 'a key resolved at runtime must be reviewed and listed',
    );

    final missing = <String>[];
    for (final locale in supportedLocales) {
      if (locale.languageCode == 'en') continue;
      for (final key in keys) {
        if (!SotyL10n.hasTranslation(locale.languageCode, key)) {
          missing.add('${locale.languageCode}: $key');
        }
      }
    }
    expect(
      missing,
      isEmpty,
      reason: 'untranslated keys: ${missing.join(', ')}',
    );
  });

  test('a language table entry renders as that language, not the key', () {
    for (final locale in supportedLocales) {
      if (locale.languageCode == 'en') continue;
      final text = SotyL10n.forLocale(locale, 'Unlock');
      expect(text, isNot('Unlock'), reason: locale.languageCode);
    }
  });

  test('the scanner still finds the two keys T-54 was filed for', () {
    final keys = _scan().map((e) => e.key).whereType<String>().toSet();
    expect(keys, contains('Failed to save photo'));
    expect(keys, contains('Photo saved to {path}'));
  });
}

/// Walks `lib/` and collects the key argument of every
/// `SotyL10n.tr(...)` / `SotyL10n.forLocale(...)` call.
List<_Found> _scan() {
  final call = RegExp(r'SotyL10n\.(?:tr|forLocale)\(');
  final out = <_Found>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final source = file.readAsStringSync();
    for (final match in call.allMatches(source)) {
      final args = _arguments(source, match.end);
      if (args.length < 2) continue;
      final raw = args[1].trim();
      final name = file.uri.pathSegments.last;
      if (raw.startsWith("'")) {
        final key = _literal(raw);
        if (key != null) out.add((source: name, key: key, dynamic: null));
      } else {
        out.add((
          source: name,
          key: null,
          dynamic: '$name:${_squash(raw)}',
        ));
        // A conditional or fallback still contains literal keys; check them.
        for (final literal in _literalsIn(raw)) {
          out.add((source: name, key: literal, dynamic: null));
        }
      }
    }
  }
  return out;
}

/// The argument list that follows the `(` at [start], split on top-level
/// commas. String literals and nested brackets are respected.
List<String> _arguments(String source, int start) {
  var depth = 1;
  var buffer = StringBuffer();
  final args = <String>[];
  var i = start;
  while (i < source.length) {
    final char = source[i];
    if (char == "'" || char == '"') {
      final end = _skipString(source, i);
      buffer.write(source.substring(i, end));
      i = end;
      continue;
    }
    if (char == '(' || char == '[' || char == '{') depth++;
    if (char == ')' || char == ']' || char == '}') {
      depth--;
      if (depth == 0) {
        args.add(buffer.toString());
        return args;
      }
    }
    if (char == ',' && depth == 1) {
      args.add(buffer.toString());
      buffer = StringBuffer();
      i++;
      continue;
    }
    buffer.write(char);
    i++;
  }
  return args;
}

/// The index just past the string literal that starts at [i].
int _skipString(String source, int i) {
  final quote = source[i];
  var j = i + 1;
  while (j < source.length) {
    if (source[j] == r'\') {
      j += 2;
      continue;
    }
    if (source[j] == quote) return j + 1;
    j++;
  }
  return j;
}

/// Decodes one Dart string literal (possibly several adjacent literals).
String? _literal(String raw) {
  final parts = _literalsIn(raw);
  if (parts.isEmpty) return null;
  return parts.join();
}

/// Every single-quoted literal in [raw], decoded.
List<String> _literalsIn(String raw) {
  final out = <String>[];
  var i = 0;
  while (i < raw.length) {
    if (raw[i] == "'") {
      final end = _skipString(raw, i);
      out.add(_decode(raw.substring(i + 1, end - 1)));
      i = end;
      continue;
    }
    i++;
  }
  return out;
}

String _decode(String body) => body
    .replaceAll(r"\'", "'")
    .replaceAll(r'\"', '"')
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\t', '\t')
    .replaceAll(r'\\', r'\');

/// Collapses whitespace so a reformatted call keeps the same allow-list entry.
String _squash(String raw) => raw.replaceAll(RegExp(r'\s+'), ' ').trim();
