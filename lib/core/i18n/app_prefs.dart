import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../security_limits.dart'
    show maxEmojiRecents, retentionOptionsDays, retentionSettingsKey;
import '../storage/settings_dao.dart';
import '../transport/host/host_transport.dart'
    show RelayMode, relayModeSettingsKey;
import 'soty_l10n.dart';

/// Persisted app preferences: language, color theme and message retention.
class AppPrefs extends ChangeNotifier {
  /// How the first launch picks a language: the first system locale the app
  /// ships, else English. A stored choice always wins over this.
  AppPrefs({
    List<Locale> Function()? systemLocales,
  }) : _systemLocales =
           systemLocales ?? (() => PlatformDispatcher.instance.locales);

  static const String localeKey = 'soty.locale';
  static const String themeKey = 'soty.theme';
  static const String storeOutgoingKey = 'soty.storeOutgoing';
  static const String backgroundKey = 'soty.background';
  static const String sendOnEnterKey = 'soty.sendOnEnter';
  static const String readReceiptsKey = 'soty.readReceipts';
  static const String emojiRecentsKey = 'soty.emojiRecents';

  final List<Locale> Function() _systemLocales;
  SettingsDao? _settings;
  Locale _locale = supportedLocales.first;
  SotyTheme _theme = SotyTheme.system;
  int _retentionDays = 30;
  bool _storeOutgoing = false;
  bool _background = true;
  bool _sendOnEnter = true;
  bool _readReceipts = true;
  RelayMode _relayMode = RelayMode.manual;
  List<String> _emojiRecents = const [];

  Locale get locale => _locale;
  SotyTheme get theme => _theme;

  /// How long (in days) this device keeps its own conversations; 0 keeps
  /// them forever.
  int get retentionDays => _retentionDays;

  /// Whether the device keeps the plaintext of its own sent messages in the
  /// local database so they stay readable after a restart. Off by default.
  bool get storeOutgoing => _storeOutgoing;

  /// Whether the foreground service keeps the mesh and relay connections
  /// alive while the app is in the background. On by default.
  bool get background => _background;

  /// Whether pressing Enter in the composer sends the message instead of
  /// inserting a new line. On by default.
  bool get sendOnEnter => _sendOnEnter;

  /// Whether opening a chat tells the counterpart their messages were read.
  /// On by default; turning it off only stops the outgoing receipts.
  bool get readReceipts => _readReceipts;

  /// How the device handles relays learned from tracker-capable hosts.
  RelayMode get relayMode => _relayMode;

  /// The most recently used emoji, newest first, for the picker's recents row.
  List<String> get emojiRecents => List.unmodifiable(_emojiRecents);

  /// Binds the persistence backend once the database is open.
  void attach(SettingsDao settings) => _settings = settings;

  Future<void> load() async {
    final settings = _settings;
    if (settings == null) return;
    final localeRaw = await settings.get(localeKey);
    final themeRaw = await settings.get(themeKey);
    final retentionRaw = await settings.get(retentionSettingsKey);
    if (localeRaw != null) {
      for (final candidate in supportedLocales) {
        if (candidate.languageCode == localeRaw) {
          _locale = candidate;
          break;
        }
      }
    } else {
      _locale = _localeFromSystem();
    }
    _theme = SotyTheme.values.firstWhere(
      (t) => t.name == themeRaw,
      orElse: () => SotyTheme.system,
    );
    final parsedRetention = int.tryParse(retentionRaw ?? '');
    if (parsedRetention != null &&
        retentionOptionsDays.contains(parsedRetention)) {
      _retentionDays = parsedRetention;
    }
    final storeOutgoingRaw = await settings.get(storeOutgoingKey);
    _storeOutgoing = storeOutgoingRaw == 'true';
    final backgroundRaw = await settings.get(backgroundKey);
    _background = backgroundRaw != 'false';
    final sendOnEnterRaw = await settings.get(sendOnEnterKey);
    _sendOnEnter = sendOnEnterRaw != 'false';
    final readReceiptsRaw = await settings.get(readReceiptsKey);
    _readReceipts = readReceiptsRaw != 'false';
    final relayModeRaw = await settings.get(relayModeSettingsKey);
    _relayMode = RelayMode.values.firstWhere(
      (mode) => mode.name == relayModeRaw,
      orElse: () => RelayMode.manual,
    );
    _emojiRecents = _parseRecents(await settings.get(emojiRecentsKey));
    notifyListeners();
  }

  Locale _localeFromSystem() {
    for (final system in _systemLocales()) {
      for (final candidate in supportedLocales) {
        if (candidate.languageCode == system.languageCode) return candidate;
      }
    }
    return supportedLocales.first;
  }

  /// Decodes a stored recents list, tolerating anything hostile or corrupt:
  /// non-JSON, a non-list, non-string members and oversized lists all reduce
  /// to a clean, bounded list of strings.
  static List<String> _parseRecents(String? raw) {
    if (raw == null) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
    if (decoded is! List) return const [];
    final out = <String>[];
    for (final item in decoded) {
      if (out.length >= maxEmojiRecents) break;
      if (item is String && item.isNotEmpty) out.add(item);
    }
    return out;
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    await _settings?.set(localeKey, locale.languageCode);
  }

  Future<void> setTheme(SotyTheme theme) async {
    _theme = theme;
    notifyListeners();
    await _settings?.set(themeKey, theme.name);
  }

  /// Persists the own-conversation retention (days, 0 = forever) and notifies
  /// listeners so the pruning policy is re-applied.
  Future<void> setRetentionDays(int days) async {
    _retentionDays = days;
    notifyListeners();
    await _settings?.set(retentionSettingsKey, '$days');
  }

  Future<void> setStoreOutgoing(bool value) async {
    _storeOutgoing = value;
    notifyListeners();
    await _settings?.set(storeOutgoingKey, '$value');
  }

  Future<void> setBackground(bool value) async {
    _background = value;
    notifyListeners();
    await _settings?.set(backgroundKey, '$value');
  }

  Future<void> setSendOnEnter(bool value) async {
    _sendOnEnter = value;
    notifyListeners();
    await _settings?.set(sendOnEnterKey, '$value');
  }

  Future<void> setReadReceipts(bool value) async {
    _readReceipts = value;
    notifyListeners();
    await _settings?.set(readReceiptsKey, '$value');
  }

  Future<void> setRelayMode(RelayMode mode) async {
    _relayMode = mode;
    notifyListeners();
    await _settings?.set(relayModeSettingsKey, mode.name);
  }

  /// Records [emoji] as the most recently used one: it moves to the front,
  /// duplicates collapse and the list is trimmed to [maxEmojiRecents].
  Future<void> noteEmoji(String emoji) async {
    if (emoji.isEmpty) return;
    final next = <String>[
      emoji,
      for (final existing in _emojiRecents)
        if (existing != emoji) existing,
    ];
    _emojiRecents = next.length > maxEmojiRecents
        ? next.sublist(0, maxEmojiRecents)
        : next;
    notifyListeners();
    await _settings?.set(emojiRecentsKey, jsonEncode(_emojiRecents));
  }
}

/// Appearance modes offered by the theme selector.
enum SotyTheme { system, light, dark }

extension SotyThemeMode on SotyTheme {
  ThemeMode toThemeMode() => switch (this) {
    SotyTheme.system => ThemeMode.system,
    SotyTheme.light => ThemeMode.light,
    SotyTheme.dark => ThemeMode.dark,
  };
}