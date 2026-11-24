import 'dart:convert';

import 'package:dtm_app/core/i18n/app_prefs.dart';
import 'package:dtm_app/core/security_limits.dart' show maxEmojiRecents;
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/settings_dao.dart';
import 'package:dtm_app/core/transport/host/host_transport.dart'
    show RelayMode, relayModeSettingsKey;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppPrefs', () {
    test('defaults to english and system theme', () {
      final prefs = AppPrefs();
      expect(prefs.locale, const Locale('en'));
      expect(prefs.theme, SotyTheme.system);
      expect(prefs.theme.toThemeMode(), ThemeMode.system);
      expect(prefs.storeOutgoing, isFalse);
      expect(prefs.background, isTrue);
      expect(prefs.sendOnEnter, isTrue);
      expect(prefs.relayMode, RelayMode.auto);
    });

    test('the first launch picks a supported system language', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final prefs = AppPrefs(
        systemLocales: () => const [Locale('sv'), Locale('ru')],
      )..attach(SettingsDao(db));
      await prefs.load();
      expect(prefs.locale, const Locale('ru'));
    });

    test('an unsupported system language falls back to english', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final prefs = AppPrefs(
        systemLocales: () => const [Locale('sv'), Locale('fi')],
      )..attach(SettingsDao(db));
      await prefs.load();
      expect(prefs.locale, const Locale('en'));
    });

    test('a stored choice wins over the system language', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      await dao.set(AppPrefs.localeKey, 'ru');
      final prefs = AppPrefs(
        systemLocales: () => const [Locale('zh')],
      )..attach(dao);
      await prefs.load();
      expect(prefs.locale, const Locale('ru'));
    });

    test('setLocale and setTheme notify and persist', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      var notified = 0;
      final prefs = AppPrefs()..attach(dao);
      prefs.addListener(() => notified++);

      await prefs.setLocale(const Locale('ru'));
      expect(prefs.locale, const Locale('ru'));
      expect(await dao.get(AppPrefs.localeKey), 'ru');

      await prefs.setTheme(SotyTheme.dark);
      expect(prefs.theme, SotyTheme.dark);
      expect(prefs.theme.toThemeMode(), ThemeMode.dark);
      expect(await dao.get(AppPrefs.themeKey), 'dark');

      await prefs.setStoreOutgoing(true);
      expect(prefs.storeOutgoing, isTrue);
      expect(await dao.get(AppPrefs.storeOutgoingKey), 'true');

      await prefs.setRelayMode(RelayMode.manual);
      expect(prefs.relayMode, RelayMode.manual);
      expect(await dao.get(relayModeSettingsKey), 'manual');

      expect(notified, 4);
    });

    test('load restores persisted values', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      await dao.set(AppPrefs.localeKey, 'ru');
      await dao.set(AppPrefs.themeKey, 'light');
      await dao.set(AppPrefs.storeOutgoingKey, 'true');
      await dao.set(relayModeSettingsKey, 'manual');

      final restored = AppPrefs()..attach(SettingsDao(db));
      await restored.load();
      expect(restored.locale, const Locale('ru'));
      expect(restored.theme, SotyTheme.light);
      expect(restored.storeOutgoing, isTrue);
      expect(restored.relayMode, RelayMode.manual);
    });

    test('load ignores unknown stored values', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      await dao.set(AppPrefs.localeKey, 'sv');
      await dao.set(AppPrefs.themeKey, 'neon');
      await dao.set(relayModeSettingsKey, 'quantum');

      final restored = AppPrefs()..attach(SettingsDao(db));
      await restored.load();
      expect(restored.locale, const Locale('en'));
      expect(restored.theme, SotyTheme.system);
      expect(restored.relayMode, RelayMode.auto);
    });

    test('setBackground notifies and persists', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      final prefs = AppPrefs()..attach(dao);
      var notified = 0;
      prefs.addListener(() => notified++);

      await prefs.setBackground(false);
      expect(prefs.background, isFalse);
      expect(await dao.get(AppPrefs.backgroundKey), 'false');

      expect(notified, 1);
    });

    test('setSendOnEnter notifies and persists', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      final prefs = AppPrefs()..attach(dao);
      var notified = 0;
      prefs.addListener(() => notified++);

      await prefs.setSendOnEnter(false);
      expect(prefs.sendOnEnter, isFalse);
      expect(await dao.get(AppPrefs.sendOnEnterKey), 'false');

      expect(notified, 1);
    });

    test('load restores a disabled send-on-enter toggle', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      await dao.set(AppPrefs.sendOnEnterKey, 'false');

      final restored = AppPrefs()..attach(SettingsDao(db));
      await restored.load();
      expect(restored.sendOnEnter, isFalse);
    });

    test('load keeps send-on-enter on when the key is absent', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final restored = AppPrefs()..attach(SettingsDao(db));
      await restored.load();
      expect(restored.sendOnEnter, isTrue);
    });

    test('load keeps background on when the key is absent', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final restored = AppPrefs()..attach(SettingsDao(db));
      await restored.load();
      expect(restored.background, isTrue);
    });

    test('read receipts default on', () {
      expect(AppPrefs().readReceipts, isTrue);
    });

    test('setReadReceipts notifies and persists', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      final prefs = AppPrefs()..attach(dao);
      var notified = 0;
      prefs.addListener(() => notified++);

      await prefs.setReadReceipts(false);
      expect(prefs.readReceipts, isFalse);
      expect(await dao.get(AppPrefs.readReceiptsKey), 'false');

      expect(notified, 1);
    });

    test('load restores a disabled read-receipts toggle', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      await dao.set(AppPrefs.readReceiptsKey, 'false');

      final restored = AppPrefs()..attach(SettingsDao(db));
      await restored.load();
      expect(restored.readReceipts, isFalse);
    });

    test('load keeps read receipts on when the key is absent', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final restored = AppPrefs()..attach(SettingsDao(db));
      await restored.load();
      expect(restored.readReceipts, isTrue);
    });

    test('load restores a disabled background toggle', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      await dao.set(AppPrefs.backgroundKey, 'false');

      final restored = AppPrefs()..attach(SettingsDao(db));
      await restored.load();
      expect(restored.background, isFalse);
    });

    test('unattached prefs still notify but do not persist', () async {
      final prefs = AppPrefs();
      var notified = 0;
      prefs.addListener(() => notified++);
      await prefs.setLocale(const Locale('ru'));
      expect(prefs.locale, const Locale('ru'));
      expect(notified, 1);
    });

    test('emoji recents start empty', () {
      expect(AppPrefs().emojiRecents, isEmpty);
    });

    test('noteEmoji moves to front, dedupes and clamps', () async {
      final prefs = AppPrefs();
      for (var i = 0; i < maxEmojiRecents + 5; i++) {
        await prefs.noteEmoji('e$i');
      }
      expect(prefs.emojiRecents, hasLength(maxEmojiRecents));
      expect(prefs.emojiRecents.first, 'e${maxEmojiRecents + 4}');

      await prefs.noteEmoji('e10');
      expect(prefs.emojiRecents.first, 'e10');
      expect(prefs.emojiRecents.where((e) => e == 'e10'), hasLength(1));
    });

    test('noteEmoji persists and load restores it', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      final prefs = AppPrefs()..attach(dao);
      await prefs.noteEmoji('😀');
      await prefs.noteEmoji('🔥');
      expect(prefs.emojiRecents, ['🔥', '😀']);

      final restored = AppPrefs()..attach(SettingsDao(db));
      await restored.load();
      expect(restored.emojiRecents, ['🔥', '😀']);
    });

    test('load turns broken recents JSON into an empty list', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      await dao.set(AppPrefs.emojiRecentsKey, 'not json at all');

      final restored = AppPrefs()..attach(SettingsDao(db));
      await restored.load();
      expect(restored.emojiRecents, isEmpty);
    });

    test('load rejects a non-list recents payload', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      await dao.set(AppPrefs.emojiRecentsKey, '{"a":1}');

      final restored = AppPrefs()..attach(SettingsDao(db));
      await restored.load();
      expect(restored.emojiRecents, isEmpty);
    });

    test('load drops non-string members and clamps the list', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      final encoded = jsonEncode([
        1,
        '😀',
        null,
        '',
        for (var i = 0; i < maxEmojiRecents + 5; i++) 'x$i',
      ]);
      await dao.set(AppPrefs.emojiRecentsKey, encoded);

      final restored = AppPrefs()..attach(SettingsDao(db));
      await restored.load();
      expect(restored.emojiRecents, hasLength(maxEmojiRecents));
      expect(restored.emojiRecents.first, '😀');
      expect(restored.emojiRecents, isNot(contains('')));
    });
  });
}