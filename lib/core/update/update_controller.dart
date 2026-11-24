import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../build_info.dart';
import '../storage/settings_dao.dart';
import 'update_client.dart';
import 'update_installer.dart';
import 'version_compare.dart';

/// What the update UI is doing right now.
enum UpdatePhase {
  /// Nothing known yet (or no check has run in this launch).
  idle,
  checking,
  upToDate,
  available,
  downloading,
  downloaded,

  /// The last check or download failed.
  failed,
}

/// Owns the app-update lifecycle: the once-a-day release check, the startup
/// banner's hide/snooze state, the APK download and the hand-off to Android's
/// package installer.
///
/// All persistence goes through [SettingsDao] under the `soty.update.*` keys,
/// so the state survives restarts; the network and the installer are injected
/// so tests never touch either.
class UpdateController extends ChangeNotifier {
  UpdateController({
    required ReleaseFeed client,
    required SettingsDao settings,
    UpdateInstaller installer = const PlatformUpdateInstaller(),
    DateTime Function()? clock,
    Future<Directory> Function()? cacheDir,
  }) : _client = client,
       _settings = settings,
       _installer = installer,
       _now = clock ?? DateTime.now,
       _cacheDir = cacheDir ?? getTemporaryDirectory;

  static const String lastCheckKey = 'soty.update.lastCheckTs';
  static const String suppressedVersionKey = 'soty.update.suppressedVersion';
  static const String snoozeUntilKey = 'soty.update.snoozeUntilTs';
  static const String releaseKey = 'soty.update.release';
  static const String lastResultKey = 'soty.update.lastResult';

  /// A successful check runs at most once per this interval.
  static const Duration checkInterval = Duration(hours: 24);

  /// A check that failed on the network is retried much sooner, so a flaky
  /// connection or a GitHub hiccup cannot hide an update for a whole day.
  /// Only a completed check earns the full [checkInterval].
  static const Duration failureRetryInterval = Duration(minutes: 5);

  /// "Remind me later" hides the banner for this long.
  static const Duration snoozeDuration = Duration(hours: 6);

  /// Shown when a downloaded APK did not match the digest in the release
  /// notes. Translated through [SotyL10n] like every other UI string.
  static const String checksumMismatchNotice =
      'The downloaded file failed its checksum check';

  /// Shown when the downloaded APK is signed with a different certificate than
  /// the installed app. Android refuses such an update, and the user has to
  /// reinstall by hand and restore a backup (T-75 migration).
  static const String signatureChangedNotice =
      'The new version is signed with a different key. Save a backup, '
      'uninstall Soty, then install the new release by hand and restore '
      'the backup.';

  /// Stable file name inside the app cache; a re-download overwrites it.
  static const String apkFileName = 'soty-update.apk';

  final ReleaseFeed _client;
  final SettingsDao _settings;
  final UpdateInstaller _installer;
  final DateTime Function() _now;
  final Future<Directory> Function() _cacheDir;

  UpdatePhase _phase = UpdatePhase.idle;
  UpdateRelease? _release;
  File? _apk;
  double? _progress;
  int? _lastCheckMs;

  /// Whether the last check failed. Restored from storage, so a restarted app
  /// keeps the short retry interval instead of waiting a day.
  bool _lastCheckFailed = false;
  String? _suppressedVersion;
  int? _snoozeUntilMs;
  bool _installBlocked = false;
  bool _disposed = false;
  String? _failureKey;

  UpdatePhase get phase => _phase;

  /// The newer release, when one is known.
  UpdateRelease? get release => _release;

  /// Whether a newer release than this build exists.
  bool get hasUpdate => _release != null;

  /// Whether the downloaded APK is on disk and ready for the installer.
  bool get readyToInstall => _apk != null;

  /// 0..1 while downloading; `null` while the total size is unknown.
  double? get progress => _progress;

  /// True after Android refused the install and the "install unknown apps"
  /// screen was opened instead.
  bool get installBlocked => _installBlocked;

  /// The English key of the specific failure the banner should show, or
  /// `null` for the generic "download failed" text. Only [UpdatePhase.failed]
  /// is user-visible, so the key is cleared whenever a new attempt starts or
  /// succeeds.
  String? get failureKey => _failureKey;

  /// When the release feed was last consulted (ms since epoch).
  int? get lastCheckMs => _lastCheckMs;

  AppVersion get currentVersion =>
      AppVersion.tryParse(kSotyVersion) ?? const AppVersion(0, 0, 0);

  /// Whether the update hint belongs on screen: a newer release exists and
  /// the user has neither hidden this version nor asked to be reminded later.
  bool get bannerVisible {
    final release = _release;
    if (release == null) return false;
    if (_phase == UpdatePhase.idle || _phase == UpdatePhase.checking) {
      return false;
    }
    return !_suppressed(release) && !_snoozed;
  }

  bool _suppressed(UpdateRelease release) {
    final raw = _suppressedVersion;
    if (raw == null) return false;
    final hidden = AppVersion.tryParse(raw);
    if (hidden == null) return false;
    // A newer version than the hidden one is announced again.
    return !release.parsed.isNewerThan(hidden);
  }

  bool get _snoozed {
    final until = _snoozeUntilMs;
    return until != null && _now().millisecondsSinceEpoch < until;
  }

  /// Loads the persisted check state. Safe to call once after the database is
  /// open, before the first [checkIfDue].
  Future<void> load() async {
    final last = int.tryParse(await _settings.get(lastCheckKey) ?? '');
    _lastCheckMs = last;
    _lastCheckFailed = await _settings.get(lastResultKey) == 'failed';
    _suppressedVersion = await _settings.get(suppressedVersionKey);
    _snoozeUntilMs = int.tryParse(await _settings.get(snoozeUntilKey) ?? '');
    // The daily gate means a launch may not re-read the feed at all; restoring
    // the last known release keeps the Settings hint honest across restarts.
    final stored = UpdateRelease.fromJson(
      await _settings.get(releaseKey) ?? '',
    );
    if (stored != null && stored.parsed.isNewerThan(currentVersion)) {
      _release = stored;
      _phase = UpdatePhase.available;
    } else {
      // No stored release means the last completed check found nothing newer;
      // the outcome is kept so the Settings row stays truthful across a
      // restart that the daily gate skips.
      _phase = switch (await _settings.get(lastResultKey)) {
        'ok' => UpdatePhase.upToDate,
        'failed' => UpdatePhase.failed,
        _ => UpdatePhase.idle,
      };
    }
    _notify();
  }

  /// Checks only when the last check is older than [checkInterval], so the
  /// feed is consulted about once a day no matter how often the app starts.
  Future<void> checkIfDue() async {
    final last = _lastCheckMs;
    final now = _now().millisecondsSinceEpoch;
    final interval = _lastCheckFailed ? failureRetryInterval : checkInterval;
    final fresh =
        last != null &&
        now >= last &&
        now - last < interval.inMilliseconds;
    if (fresh) return;
    await check();
  }

  /// Consults the release feed. A failure never throws: it turns into
  /// [UpdatePhase.failed] so the UI can offer a retry.
  Future<void> check() async {
    if (_phase == UpdatePhase.checking || _phase == UpdatePhase.downloading) {
      return;
    }
    _phase = UpdatePhase.checking;
    _progress = null;
    _notify();
    try {
      final release = await _client.fetchLatest();
      await _noteCheck(failed: false);
      if (release == null || !release.parsed.isNewerThan(currentVersion)) {
        _release = null;
        _apk = null;
        _phase = UpdatePhase.upToDate;
        await _settings.remove(releaseKey);
        await _settings.set(lastResultKey, 'ok');
        return;
      }
      _release = release;
      _apk = null;
      _phase = UpdatePhase.available;
      await _settings.set(releaseKey, release.toJson());
      await _settings.set(lastResultKey, 'ok');
    } on UpdateCheckException catch (error) {
      debugPrint('Soty update check failed: ${error.message}');
      await _noteCheck(failed: true);
      await _settings.set(lastResultKey, 'failed');
      _phase = _release == null ? UpdatePhase.failed : UpdatePhase.available;
    } finally {
      _notify();
    }
  }

  Future<void> _noteCheck({required bool failed}) async {
    final now = _now().millisecondsSinceEpoch;
    _lastCheckMs = now;
    _lastCheckFailed = failed;
    await _settings.set(lastCheckKey, '$now');
  }

  /// Hides the banner for this release only: a newer one shows it again.
  Future<void> hideBanner() async {
    final release = _release;
    if (release == null) return;
    _suppressedVersion = release.version;
    _notify();
    await _settings.set(suppressedVersionKey, release.version);
  }

  /// Hides the banner for [snoozeDuration].
  Future<void> snoozeBanner() async {
    final until = _now().add(snoozeDuration).millisecondsSinceEpoch;
    _snoozeUntilMs = until;
    _notify();
    await _settings.set(snoozeUntilKey, '$until');
  }

  /// Release notes for the running version: cached when the last check
  /// fetched that same tag, otherwise fetched on demand.
  Future<String?> notesForRunningVersion() async {
    final release = _release;
    if (release != null && release.version == kSotyVersion) {
      return release.notes;
    }
    try {
      return await _client.fetchTagNotes(kSotyVersion);
    } catch (_) {
      return release?.notes;
    }
  }

  /// Downloads the APK into the app cache. A second call while the file is
  /// already there is a no-op.
  Future<void> download() async {
    final release = _release;
    if (release == null) return;
    if (_phase == UpdatePhase.downloading) return;
    final existing = _apk;
    if (existing != null && await existing.exists()) {
      _phase = UpdatePhase.downloaded;
      _notify();
      return;
    }
    _phase = UpdatePhase.downloading;
    _progress = 0;
    _failureKey = null;
    _notify();
    try {
      final dir = await _cacheDir();
      final updates = Directory(
        '${dir.path}${Platform.pathSeparator}updates',
      );
      final file = File(
        '${updates.path}${Platform.pathSeparator}$apkFileName',
      );
      await _client.download(
        release,
        file,
        onProgress: (value) {
          _progress = value;
          _notify();
        },
      );
      final installedSigner = await _installer.signerSha256(null);
      final downloadedSigner = await _installer.signerSha256(file.path);
      if (installedSigner != null &&
          downloadedSigner != null &&
          installedSigner != downloadedSigner) {
        // Android will refuse the install; deleting the file stops a retry
        // loop and the banner explains the manual migration instead.
        await file.delete();
        _apk = null;
        _progress = null;
        _failureKey = signatureChangedNotice;
        _phase = UpdatePhase.failed;
        return;
      }
      _apk = file;
      _phase = UpdatePhase.downloaded;
    } on UpdateChecksumException {
      // The bytes on disk are not the file the release advertises; they were
      // deleted by the client, so there is nothing to install and the user is
      // told why instead of getting a generic failure.
      _apk = null;
      _progress = null;
      _failureKey = checksumMismatchNotice;
      _phase = UpdatePhase.failed;
    } on UpdateCheckException {
      _apk = null;
      _progress = null;
      _phase = UpdatePhase.failed;
    } on IOException {
      _apk = null;
      _progress = null;
      _phase = UpdatePhase.failed;
    } finally {
      _notify();
    }
  }

  /// Hands the downloaded APK to the platform installer. When the app is not
  /// allowed to install packages, the platform opens its "install unknown
  /// apps" screen and [installBlocked] stays true until the next attempt.
  Future<InstallLaunch> install() async {
    final apk = _apk;
    if (apk == null || !await apk.exists()) {
      _installBlocked = false;
      return InstallLaunch.unavailable;
    }
    final result = await _installer.install(apk.path);
    _installBlocked = result == InstallLaunch.needsPermission;
    _notify();
    return result;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
