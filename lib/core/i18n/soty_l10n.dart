import 'package:flutter/widgets.dart';

part 'locales/ru.dart';
part 'locales/zh.dart';
part 'locales/hi.dart';
part 'locales/es.dart';
part 'locales/fr.dart';
part 'locales/ar.dart';
part 'locales/bn.dart';
part 'locales/pt.dart';
part 'locales/id.dart';
part 'locales/de.dart';
part 'locales/it.dart';
part 'locales/tr.dart';
part 'locales/ja.dart';
part 'locales/ko.dart';
part 'locales/th.dart';
part 'locales/vi.dart';

/// Locales the app ships in. The first entry is the default.
const List<Locale> supportedLocales = [
  Locale('en'),
  Locale('zh'),
  Locale('hi'),
  Locale('es'),
  Locale('fr'),
  Locale('ar'),
  Locale('bn'),
  Locale('pt'),
  Locale('ru'),
  Locale('id'),
  Locale('de'),
  Locale('it'),
  Locale('tr'),
  Locale('ja'),
  Locale('ko'),
  Locale('th'),
  Locale('vi'),
];

const List<String> _supportedCodes = [
  'en',
  'zh',
  'hi',
  'es',
  'fr',
  'ar',
  'bn',
  'pt',
  'ru',
  'id',
  'de',
  'it',
  'tr',
  'ja',
  'ko',
  'th',
  'vi',
];

/// Native names shown in the language picker, keyed by language code.
const Map<String, String> _nativeNames = {
  'en': 'English',
  'zh': '中文',
  'hi': 'हिन्दी',
  'es': 'Español',
  'fr': 'Français',
  'ar': 'العربية',
  'bn': 'বাংলা',
  'pt': 'Português',
  'ru': 'Русский',
  'id': 'Bahasa Indonesia',
  'de': 'Deutsch',
  'it': 'Italiano',
  'tr': 'Türkçe',
  'ja': '日本語',
  'ko': '한국어',
  'th': 'ไทย',
  'vi': 'Tiếng Việt',
};

/// Shown when a stored app-lock verifier could not be parsed and was dropped.
const String appLockResetNotice =
    'App lock was reset: the saved password was damaged. '
    'Set it again in Settings.';

/// One table per language, keyed by the English source string. English is the
/// fallback key itself, so untranslated entries render English.
/// Keys rendered identically in every language: the brand, and the handful of
/// words a language borrows unchanged. Consulted only when a language table
/// has no entry, so a real translation always wins, and listed centrally so
/// the "every key is translated" test can see the decision instead of a
/// silent English fallback.
const Map<String, String> _unchangedKeys = {
  'Soty': 'Soty',
  'Emoji': 'Emoji',
  'Chats': 'Chats',
  'Host': 'Host',
  'Version': 'Version',
  'Photo': 'Photo',
  'online': 'online',
  'offline': 'offline',
};

const Map<String, Map<String, String>> _tables = {
  'zh': _zh,
  'hi': _hi,
  'es': _es,
  'fr': _fr,
  'ar': _ar,
  'bn': _bn,
  'pt': _pt,
  'ru': _ru,
  'id': _id,
  'de': _de,
  'it': _it,
  'tr': _tr,
  'ja': _ja,
  'ko': _ko,
  'th': _th,
  'vi': _vi,
};

/// Russian translations keyed by the English source string. English is the
/// fallback key itself, so untranslated entries render English. Numeric
/// strings may add per-category forms under `'…|one|‥|few|…'` suffixes
/// resolved by [SotyL10n.pluralCategory].

/// Simplified Chinese translations.

/// Hindi translations.

/// Spanish translations.

/// French translations.

/// Arabic translations.

/// Bengali translations.

/// Portuguese translations.

/// Indonesian translations.

/// CLDR cardinal plural categories for the shipped locales, used to pick the
/// per-category form of a numeric string (suffixed `'…|one'`/`'few'`/...).
/// Returns 'other' for codes without an explicit plural split.
String _pluralCategory(String code, int n) {
  switch (code) {
    case 'ru':
      if (n % 10 == 1 && n % 100 != 11) return 'one';
      if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14)) {
        return 'few';
      }
      if (n % 10 == 0 || (n % 10 >= 5 && n % 10 <= 9) ||
          (n % 100 >= 11 && n % 100 <= 14)) {
        return 'many';
      }
      return 'other';
    case 'ar':
      if (n == 0) return 'zero';
      if (n == 1) return 'one';
      if (n == 2) return 'two';
      final mod100 = n % 100;
      if (mod100 >= 3 && mod100 <= 10) return 'few';
      if (mod100 >= 11 && mod100 <= 99) return 'many';
      return 'other';
    case 'es':
    case 'pt':
    case 'hi':
    case 'bn':
    case 'de':
    case 'it':
    case 'tr':
      return n == 1 ? 'one' : 'other';
    case 'fr':
      return (n == 0 || n == 1) ? 'one' : 'other';
    case 'en':
    case 'zh':
    case 'id':
    default:
      return 'other';
  }
}

/// Makes the active locale visible to the widget tree. Inserted by
/// MaterialApp.builder so it wraps every route including snackbar contexts.
class SotyL10n extends InheritedWidget {
  const SotyL10n({super.key, required this.locale, required super.child});

  final Locale locale;

  /// Reads the scope above [context]; English when absent (e.g. in tests).
  static SotyL10n? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SotyL10n>();

  /// Localizes [key] for the locale above [context]. `{name}` placeholders
  /// in the value are replaced from [args]; a numeric `n` also picks the
  /// locale's plural category (`'…|one'`, `'few'`, ...) before falling back.
  static String tr(
    BuildContext context,
    String key, [
    Map<String, Object> args = const {},
  ]) {
    final locale = maybeOf(context)?.locale ?? const Locale('en');
    return forLocale(locale, key, args);
  }

  /// Localizes [key] for an explicit [locale] without a BuildContext.
  static String forLocale(
    Locale locale,
    String key, [
    Map<String, Object> args = const {},
  ]) {
    final n = int.tryParse('${args['n'] ?? ''}');
    var text = _resolve(locale.languageCode, key, n);
    for (final entry in args.entries) {
      text = text.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return text;
  }

  static String _resolve(String code, String key, int? n) {
    final table = _tables[code];
    if (table == null) return key;
    if (n != null) {
      final cat = _pluralCategory(code, n);
      final catKey = '$key|$cat';
      if (table.containsKey(catKey)) return table[catKey]!;
    }
    return table[key] ?? _unchangedKeys[key] ?? key;
  }

  /// Whether [key] has a real entry for [code] (English is the source
  /// language, so every key exists there). Used by the translation test to
  /// require an entry rather than an English fallback; a key that is the same
  /// in a language still needs an explicit [_unchangedKeys] entry.
  static bool hasTranslation(String code, String key) {
    if (code == 'en') return true;
    final table = _tables[code];
    if (table == null) return false;
    return table.containsKey(key) || _unchangedKeys.containsKey(key);
  }

  static bool isSupported(Locale locale) =>
      _supportedCodes.contains(locale.languageCode);

  /// Native name of [locale] for the language picker; the language code when
  /// unknown.
  static String languageName(Locale locale) =>
      _nativeNames[locale.languageCode] ?? locale.languageCode;

  @override
  bool updateShouldNotify(SotyL10n oldWidget) => oldWidget.locale != locale;
}