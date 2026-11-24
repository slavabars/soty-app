import 'dart:io';

import 'package:dtm_app/core/build_info.dart';
import 'package:dtm_app/core/security_limits.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/settings_dao.dart';
import 'package:dtm_app/core/update/update_client.dart';
import 'package:dtm_app/core/update/update_controller.dart';
import 'package:dtm_app/core/update/update_installer.dart';
import 'package:dtm_app/core/update/version_compare.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeFeed implements ReleaseFeed {
  _FakeFeed({this.release, this.error});

  UpdateRelease? release;
  UpdateCheckException? error;
  List<int> bytes = const [1, 2, 3];
  int fetches = 0;
  int downloads = 0;
  Object? downloadError;
  bool tooLarge = false;
  String? tagNotes;

  @override
  Future<String?> fetchTagNotes(String version) async => tagNotes;

  @override
  Future<UpdateRelease?> fetchLatest() async {
    fetches++;
    final failure = error;
    if (failure != null) throw failure;
    return release;
  }

  @override
  Future<int> download(
    UpdateRelease release,
    File target, {
    void Function(double? progress)? onProgress,
  }) async {
    downloads++;
    final failure = downloadError;
    if (failure != null) throw failure;
    if (tooLarge) throw const UpdateCheckException('asset too large');
    await target.create(recursive: true);
    await target.writeAsBytes(bytes);
    onProgress?.call(1);
    return bytes.length;
  }
}

UpdateRelease _release(String version) => UpdateRelease(
  version: version,
  parsed: AppVersion.tryParse(version)!,
  apkUrl: 'https://github.com/slavabars/soty/releases/download/x/a.apk',
  apkSize: 3,
  notes: 'notes',
);

void main() {
  late AppDatabase db;
  late SettingsDao settings;
  late Directory cache;
  var ms = DateTime.utc(2026, 10, 20, 12).millisecondsSinceEpoch;

  DateTime clock() => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

  UpdateController controllerFor(
    _FakeFeed feed, {
    UpdateInstaller installer = const PlatformUpdateInstaller(),
  }) {
    return UpdateController(
      client: feed,
      settings: settings,
      installer: installer,
      clock: clock,
      cacheDir: () async => cache,
    );
  }

  setUp(() async {
    db = AppDatabase.inMemory();
    settings = SettingsDao(db);
    cache = await Directory.systemTemp.createTemp('soty-update-controller');
    ms = DateTime.utc(2026, 10, 20, 12).millisecondsSinceEpoch;
  });

  tearDown(() async {
    await cache.delete(recursive: true);
    await db.close();
  });

  group('running version notes', () {
    test('the notes of the running tag are fetched when the feed is newer',
        () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'))
        ..tagNotes = '## Что нового\n- fix';
      final c = controllerFor(feed);
      await c.check();
      expect(await c.notesForRunningVersion(), '## Что нового\n- fix');
    });

    test('a failed tag lookup yields null instead of throwing', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'))
        ..tagNotes = null;
      final c = controllerFor(feed);
      await c.check();
      expect(await c.notesForRunningVersion(), isNull);
    });
  });

  group('check', () {
    test('a newer release becomes available and is reported', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final c = controllerFor(feed);
      await c.load();
      await c.check();

      expect(c.phase, UpdatePhase.available);
      expect(c.hasUpdate, isTrue);
      expect(c.release!.version, '9.9.9+99');
      expect(c.bannerVisible, isTrue);
      expect(feed.fetches, 1);
    });

    test('the running version is not an update', () async {
      final feed = _FakeFeed(release: _release(kSotyVersion));
      final c = controllerFor(feed);
      await c.check();

      expect(c.phase, UpdatePhase.upToDate);
      expect(c.hasUpdate, isFalse);
      expect(c.bannerVisible, isFalse);
    });

    test('an older advertised release is not an update', () async {
      final feed = _FakeFeed(release: _release('0.0.1'));
      final c = controllerFor(feed);
      await c.check();

      expect(c.phase, UpdatePhase.upToDate);
      expect(c.hasUpdate, isFalse);
    });

    test('a feed with nothing installable is "up to date"', () async {
      final feed = _FakeFeed();
      final c = controllerFor(feed);
      await c.check();

      expect(c.phase, UpdatePhase.upToDate);
      expect(c.hasUpdate, isFalse);
    });

    test('a failed check turns into failed, not an exception', () async {
      final feed = _FakeFeed(error: const UpdateCheckException('offline'));
      final c = controllerFor(feed);
      await c.check();

      expect(c.phase, UpdatePhase.failed);
      expect(c.hasUpdate, isFalse);
      expect(c.bannerVisible, isFalse);
    });

    test('a failed re-check keeps the release already known', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final c = controllerFor(feed);
      await c.check();
      expect(c.hasUpdate, isTrue);

      feed.error = const UpdateCheckException('offline');
      await c.check();
      expect(c.phase, UpdatePhase.available);
      expect(c.release!.version, '9.9.9+99');
      expect(c.bannerVisible, isTrue);
    });

    test('the check timestamp is persisted on success and failure', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final c = controllerFor(feed);
      await c.check();
      expect(
        await settings.get(UpdateController.lastCheckKey),
        '$ms',
      );

      feed.error = const UpdateCheckException('offline');
      await c.check();
      expect(await settings.get(UpdateController.lastCheckKey), '$ms');
    });
  });

  group('once a day', () {
    test('checkIfDue skips a recent check and runs an old one', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final c = controllerFor(feed);
      await c.load();
      await c.checkIfDue();
      expect(feed.fetches, 1);

      ms += const Duration(hours: 23).inMilliseconds;
      await c.checkIfDue();
      expect(feed.fetches, 1, reason: 'still inside the 24h window');

      ms += const Duration(hours: 2).inMilliseconds;
      await c.checkIfDue();
      expect(feed.fetches, 2);
    });

    test('a failed check is retried after five minutes, not a day',
        () async {
      final feed = _FakeFeed()..error = const UpdateCheckException('offline');
      final c = controllerFor(feed);
      await c.load();
      await c.checkIfDue();
      expect(feed.fetches, 1);
      expect(c.phase, UpdatePhase.failed);

      ms += const Duration(minutes: 4).inMilliseconds;
      await c.checkIfDue();
      expect(feed.fetches, 1, reason: 'still inside the short retry window');

      ms += const Duration(minutes: 2).inMilliseconds;
      await c.checkIfDue();
      expect(feed.fetches, 2, reason: 'a failure never costs a whole day');
    });

    test('the short retry window survives a restart', () async {
      final feed = _FakeFeed()..error = const UpdateCheckException('offline');
      final first = controllerFor(feed);
      await first.load();
      await first.checkIfDue();
      expect(feed.fetches, 1);

      ms += const Duration(minutes: 6).inMilliseconds;
      final second = controllerFor(feed);
      await second.load();
      await second.checkIfDue();
      expect(feed.fetches, 2);
    });

    test('a successful check restores the daily gate', () async {
      final feed = _FakeFeed()..error = const UpdateCheckException('offline');
      final c = controllerFor(feed);
      await c.load();
      await c.checkIfDue();
      expect(feed.fetches, 1);

      ms += const Duration(minutes: 6).inMilliseconds;
      feed.error = null;
      await c.checkIfDue();
      expect(feed.fetches, 2);
      expect(c.phase, UpdatePhase.upToDate);

      ms += const Duration(minutes: 30).inMilliseconds;
      await c.checkIfDue();
      expect(feed.fetches, 2, reason: 'back to the 24h window');
    });

    test('the daily gate survives a restart', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final first = controllerFor(feed);
      await first.load();
      await first.checkIfDue();

      final second = controllerFor(feed);
      await second.load();
      await second.checkIfDue();
      expect(feed.fetches, 1);
    });

    test('a release found once survives a restart inside the daily window',
        () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final first = controllerFor(feed);
      await first.check();
      expect(first.hasUpdate, isTrue);

      final second = controllerFor(feed);
      await second.load();
      await second.checkIfDue();
      expect(feed.fetches, 1, reason: 'the daily gate still applies');
      expect(second.hasUpdate, isTrue);
      expect(second.release!.version, '9.9.9+99');
      expect(second.bannerVisible, isTrue);
      expect(second.readyToInstall, isFalse);
    });

    test('a later up-to-date check forgets the stored release', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final c = controllerFor(feed);
      await c.check();
      expect(await settings.get(UpdateController.releaseKey), isNotNull);

      ms += const Duration(days: 2).inMilliseconds;
      feed.release = null;
      await c.checkIfDue();
      expect(c.hasUpdate, isFalse);
      expect(await settings.get(UpdateController.releaseKey), isNull);
    });

    test('a stored release older than this build is ignored on load',
        () async {
      await settings.set(
        UpdateController.releaseKey,
        _release('0.0.1').toJson(),
      );
      final feed = _FakeFeed();
      final c = controllerFor(feed);
      await c.load();
      expect(c.hasUpdate, isFalse);
      expect(c.phase, UpdatePhase.idle);
    });

    test('an up-to-date check is remembered across a restart', () async {
      final feed = _FakeFeed(release: _release(kSotyVersion));
      final first = controllerFor(feed);
      await first.check();
      expect(first.phase, UpdatePhase.upToDate);

      final second = controllerFor(feed);
      await second.load();
      expect(second.phase, UpdatePhase.upToDate);
      expect(second.hasUpdate, isFalse);
    });

    test('a failed check is remembered as failed, not as up to date',
        () async {
      final feed = _FakeFeed(error: const UpdateCheckException('offline'));
      final first = controllerFor(feed);
      await first.check();
      expect(first.phase, UpdatePhase.failed);

      final second = controllerFor(feed);
      await second.load();
      expect(second.phase, UpdatePhase.failed);
      expect(second.hasUpdate, isFalse);
    });

    test('a restarted controller with no history stays idle', () async {
      final feed = _FakeFeed();
      final c = controllerFor(feed);
      await c.load();
      expect(c.phase, UpdatePhase.idle);
      expect(c.hasUpdate, isFalse);
    });

    test('a corrupt stored release is ignored on load', () async {
      await settings.set(UpdateController.releaseKey, 'not json');
      final feed = _FakeFeed();
      final c = controllerFor(feed);
      await c.load();
      expect(c.hasUpdate, isFalse);
      await c.check();
      expect(c.phase, UpdatePhase.upToDate);
    });

    test('a timestamp from the future does not silence the check', () async {
      await settings.set(
        UpdateController.lastCheckKey,
        '${ms + const Duration(days: 30).inMilliseconds}',
      );
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final c = controllerFor(feed);
      await c.load();
      await c.checkIfDue();
      expect(feed.fetches, 1);
    });
  });

  group('hide and snooze', () {
    test('hide suppresses this version only', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final c = controllerFor(feed);
      await c.check();
      await c.hideBanner();
      expect(c.bannerVisible, isFalse);
      expect(c.hasUpdate, isTrue, reason: 'settings still shows the update');
      expect(
        await settings.get(UpdateController.suppressedVersionKey),
        '9.9.9+99',
      );

      feed.release = _release('9.9.10');
      await c.check();
      expect(c.bannerVisible, isTrue, reason: 'a newer version shows again');
    });

    test('a hidden version stays hidden after a restart', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final first = controllerFor(feed);
      await first.check();
      await first.hideBanner();

      final second = controllerFor(feed);
      await second.load();
      await second.checkIfDue();
      expect(feed.fetches, 1, reason: 'the daily gate still applies');
      expect(second.hasUpdate, isTrue, reason: 'the release is restored');
      expect(second.bannerVisible, isFalse, reason: 'hidden for this one');

      ms += const Duration(days: 2).inMilliseconds;
      await second.checkIfDue();
      expect(second.bannerVisible, isFalse);
    });

    test('a corrupt stored version does not hide anything', () async {
      await settings.set(
        UpdateController.suppressedVersionKey,
        'not a version',
      );
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final c = controllerFor(feed);
      await c.load();
      await c.check();
      expect(c.bannerVisible, isTrue);
    });

    test('snooze hides for six hours and then shows again', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final c = controllerFor(feed);
      await c.check();
      await c.snoozeBanner();
      expect(c.bannerVisible, isFalse);

      ms += const Duration(hours: 5, minutes: 59).inMilliseconds;
      expect(c.bannerVisible, isFalse);
      ms += const Duration(minutes: 2).inMilliseconds;
      expect(c.bannerVisible, isTrue);
    });
  });

  group('download and install', () {
    test('download stores the apk and switches the button to install',
        () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final c = controllerFor(feed);
      await c.check();
      await c.download();

      expect(c.phase, UpdatePhase.downloaded);
      expect(c.readyToInstall, isTrue);
      expect(feed.downloads, 1);
      final file = File(
        '${cache.path}${Platform.pathSeparator}updates'
        '${Platform.pathSeparator}${UpdateController.apkFileName}',
      );
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), [1, 2, 3]);
      expect(c.bannerVisible, isTrue);
    });

    test('a second download reuses the file', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final c = controllerFor(feed);
      await c.check();
      await c.download();
      await c.download();
      expect(feed.downloads, 1);
    });

    test('a failed download is a failure with nothing to install', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'))
        ..downloadError = const UpdateCheckException('offline');
      final c = controllerFor(feed);
      await c.check();
      await c.download();

      expect(c.phase, UpdatePhase.failed);
      expect(c.readyToInstall, isFalse);
      expect(c.installBlocked, isFalse);
    });

    test('a checksum mismatch is refused with its own message', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'))
        ..downloadError = const UpdateChecksumException();
      final c = controllerFor(feed);
      await c.check();
      await c.download();

      expect(c.phase, UpdatePhase.failed);
      expect(c.readyToInstall, isFalse);
      expect(c.failureKey, UpdateController.checksumMismatchNotice);
      expect(
        c.bannerVisible,
        isTrue,
        reason: 'the banner explains the refusal',
      );

      // A successful retry clears the specific reason.
      feed.downloadError = null;
      await c.download();
      expect(c.phase, UpdatePhase.downloaded);
      expect(c.failureKey, isNull);
    });

    test('an APK signed with another key is refused with the migration notice',
        () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final fake = _FakeInstaller(InstallLaunch.started)
        ..signers[null] = 'aaaa'
        ..anyPathSigner = 'bbbb';
      final c = controllerFor(feed, installer: fake.installer);
      await c.check();
      await c.download();

      expect(c.phase, UpdatePhase.failed);
      expect(c.failureKey, UpdateController.signatureChangedNotice);
      expect(c.readyToInstall, isFalse);
      expect(fake.paths, isEmpty);
    });

    test('an update with the same signer is installed normally', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final fake = _FakeInstaller(InstallLaunch.started)
        ..signers[null] = 'aaaa'
        ..anyPathSigner = 'aaaa';
      final c = controllerFor(feed, installer: fake.installer);
      await c.check();
      await c.download();

      expect(c.phase, UpdatePhase.downloaded);
      expect(c.readyToInstall, isTrue);
      expect(c.failureKey, isNull);
    });

    test('a generic failure carries no specific message', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'))
        ..downloadError = const UpdateCheckException('offline');
      final c = controllerFor(feed);
      await c.check();
      await c.download();
      expect(c.failureKey, isNull);
    });

    test('an over-size asset leaves no file and no install', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'))..tooLarge = true;
      final c = controllerFor(feed);
      await c.check();
      await c.download();
      expect(c.readyToInstall, isFalse);
      expect(c.phase, UpdatePhase.failed);
    });

    test('install without a downloaded file is unavailable', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final c = controllerFor(feed);
      await c.check();
      expect(await c.install(), InstallLaunch.unavailable);
    });

    test('a blocked install is surfaced until the next attempt', () async {
      final feed = _FakeFeed(release: _release('9.9.9+99'));
      final blocked = _FakeInstaller(InstallLaunch.needsPermission);
      final c = controllerFor(feed, installer: blocked.installer);
      await c.check();
      await c.download();

      expect(await c.install(), InstallLaunch.needsPermission);
      expect(c.installBlocked, isTrue);

      blocked.result = InstallLaunch.started;
      expect(await c.install(), InstallLaunch.started);
      expect(c.installBlocked, isFalse);
    });
  });

  test('the size cap used by the client is the shared limit', () {
    expect(maxUpdateApkBytes, 200 * 1024 * 1024);
  });
}

/// Routes the installer calls to an in-memory result instead of a channel.
final class _FakeInstaller {
  _FakeInstaller(this.result);

  InstallLaunch result;
  final List<String> paths = [];
  final Map<String?, String?> signers = {};
  String? anyPathSigner;

  UpdateInstaller get installer => _ChannelInstaller(this);
}

final class _ChannelInstaller implements UpdateInstaller {
  _ChannelInstaller(this.owner);

  final _FakeInstaller owner;

  @override
  Future<String?> signerSha256(String? path) async => path == null
      ? owner.signers[path]
      : (owner.signers[path] ?? owner.anyPathSigner);

  @override
  Future<bool> canInstall() async => true;

  @override
  Future<InstallLaunch> install(String path) async {
    owner.paths.add(path);
    return owner.result;
  }
}
