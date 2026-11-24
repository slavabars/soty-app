import 'package:dtm_app/core/i18n/soty_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SotyL10n', () {
    test('english falls back to the source key', () {
      expect(SotyL10n.forLocale(const Locale('en'), 'Unlock'), 'Unlock');
    });

    test('russian resolves known keys', () {
      expect(
        SotyL10n.forLocale(const Locale('ru'), 'Unlock'),
        'Разблокировать',
      );
      expect(
        SotyL10n.forLocale(const Locale('ru'), 'Settings'),
        'Настройки',
      );
      expect(
        SotyL10n.forLocale(const Locale('ru'), 'Send with Enter'),
        'Отправлять по Enter',
      );
    });

    test('send-failure keys resolve in russian', () {
      expect(
        SotyL10n.forLocale(
          const Locale('ru'),
          'Message exceeds the 4 KB limit',
        ),
        'Сообщение превышает лимит 4 КБ',
      );
      expect(
        SotyL10n.forLocale(const Locale('ru'), 'Message could not be sent'),
        'Сообщение не удалось отправить',
      );
    });

    test('reply and emoji keys resolve in russian', () {
      expect(SotyL10n.forLocale(const Locale('ru'), 'Reply'), 'Ответить');
      expect(SotyL10n.forLocale(const Locale('ru'), 'Forward'), 'Переслать');
      expect(SotyL10n.forLocale(const Locale('ru'), 'Copy'), 'Копировать');
      expect(SotyL10n.forLocale(const Locale('ru'), 'Share'), 'Поделиться');
      expect(SotyL10n.forLocale(const Locale('ru'), 'Emoji'), 'Эмодзи');
      expect(SotyL10n.forLocale(const Locale('ru'), 'Recent'), 'Недавние');
      expect(
        SotyL10n.forLocale(const Locale('ru'), 'No recent emoji'),
        'Нет недавних эмодзи',
      );
      expect(
        SotyL10n.forLocale(const Locale('ru'), 'Animals & nature'),
        'Животные и природа',
      );
    });

    test('the encrypted-message banner body resolves in every locale', () {
      const key = 'Encrypted message';
      expect(SotyL10n.forLocale(const Locale('en'), key), key);
      for (final locale in supportedLocales) {
        final text = SotyL10n.forLocale(locale, key);
        expect(text, isNotEmpty, reason: 'missing ${locale.languageCode}');
        if (locale.languageCode != 'en') {
          expect(
            text,
            isNot(key),
            reason: 'untranslated ${locale.languageCode}',
          );
        }
      }
    });

    test('every update string is translated in every locale', () {
      const keys = [
        'Update available',
        'Version {v} is available',
        'Download',
        'Install',
        'Hide',
        'Remind later',
        'Allow Soty to install apps, then tap Install again.',
        'Download failed',
        'Check for updates',
        'Could not check for updates',
        'You have the latest version',
        'Current version: {v}',
        'Release notes',
        'Close',
      ];
      for (final locale in supportedLocales) {
        if (locale.languageCode == 'en') continue;
        for (final key in keys) {
          final text = SotyL10n.forLocale(locale, key);
          expect(
            text,
            isNot(key),
            reason: 'untranslated ${locale.languageCode}: $key',
          );
        }
      }
    });

    test('the app-lock reset notice is translated in every locale', () {
      for (final locale in supportedLocales) {
        final text = SotyL10n.forLocale(locale, appLockResetNotice);
        expect(text, isNotEmpty, reason: locale.languageCode);
        if (locale.languageCode != 'en') {
          expect(
            text,
            isNot(appLockResetNotice),
            reason: 'untranslated ${locale.languageCode}',
          );
        }
      }
    });

    test('the update version placeholder is interpolated', () {
      for (final locale in supportedLocales) {
        final text = SotyL10n.forLocale(
          locale,
          'Version {v} is available',
          {'v': '9.9.9+99'},
        );
        expect(text, contains('9.9.9+99'), reason: locale.languageCode);
        expect(text, isNot(contains('{v}')), reason: locale.languageCode);
      }
    });

    test('unknown key returns the key itself', () {
      expect(
        SotyL10n.forLocale(const Locale('ru'), 'No such string'),
        'No such string',
      );
    });

    test('placeholders are interpolated', () {
      expect(
        SotyL10n.forLocale(
          const Locale('ru'),
          'count: {n}\n{root}',
          {'n': '3', 'root': 'abc'},
        ),
        'количество: 3\nabc',
      );
    });

    test('supported locale detection', () {
      expect(SotyL10n.isSupported(const Locale('en')), isTrue);
      expect(SotyL10n.isSupported(const Locale('ru')), isTrue);
      expect(SotyL10n.isSupported(const Locale('de')), isTrue);
      expect(SotyL10n.isSupported(const Locale('xx')), isFalse);
    });

    test('every supported locale has a native name', () {
      for (final locale in supportedLocales) {
        expect(
          SotyL10n.languageName(locale),
          isNot(locale.languageCode),
          reason: locale.languageCode,
        );
      }
    });

    test('wave-one locales announce their native name', () {
      const names = {
        'de': 'Deutsch',
        'it': 'Italiano',
        'tr': 'Türkçe',
        'ja': '日本語',
        'ko': '한국어',
        'th': 'ไทย',
        'vi': 'Tiếng Việt',
      };
      for (final entry in names.entries) {
        expect(
          SotyL10n.languageName(Locale(entry.key)),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('wave-one plural forms pick the one category', () {
      for (final code in ['de', 'it', 'tr']) {
        final one = SotyL10n.forLocale(
          Locale(code),
          '{n} days',
          {'n': '1'},
        );
        final many = SotyL10n.forLocale(
          Locale(code),
          '{n} days',
          {'n': '5'},
        );
        expect(one, contains('1'));
        expect(many, contains('5'));
        expect(one, isNot(many), reason: code);
      }
    });

    testWidgets('tr reads the scope locale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => SotyL10n(
            locale: const Locale('ru'),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: Text('x')),
        ),
      );
      final ctx = tester.element(find.byType(Scaffold));
      expect(SotyL10n.tr(ctx, 'Unlock'), 'Разблокировать');
    });

    testWidgets('tr defaults to english without a scope', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('x'))),
      );
      final ctx = tester.element(find.byType(Scaffold));
      expect(SotyL10n.tr(ctx, 'Unlock'), 'Unlock');
    });
  });
}