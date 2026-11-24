import 'dart:io';

import 'package:dtm_app/core/storage/settings_dao.dart';
import 'package:dtm_app/core/update/update_client.dart';
import 'package:dtm_app/core/update/update_controller.dart';
import 'package:dtm_app/core/update/update_installer.dart';
import 'package:dtm_app/core/update/version_compare.dart';

/// A release feed whose answer (or failure) the test chooses.
final class FakeFeed implements ReleaseFeed {
  FakeFeed(this.release);

  UpdateRelease? release;
  bool failDownload = false;
  int downloads = 0;
  String? tagNotes;

  @override
  Future<String?> fetchTagNotes(String version) async => tagNotes;

  @override
  Future<UpdateRelease?> fetchLatest() async => release;

  @override
  Future<int> download(
    UpdateRelease release,
    File target, {
    void Function(double? progress)? onProgress,
  }) async {
    downloads++;
    if (failDownload) throw const UpdateCheckException('offline');
    await target.create(recursive: true);
    await target.writeAsBytes(const [1, 2, 3]);
    onProgress?.call(1);
    return 3;
  }
}

/// Records the install hand-off instead of reaching a platform channel.
final class FakeInstaller implements UpdateInstaller {
  InstallLaunch result = InstallLaunch.started;
  final List<String> paths = [];

  @override
  Future<String?> signerSha256(String? path) async => null;

  @override
  Future<bool> canInstall() async => result != InstallLaunch.needsPermission;

  @override
  Future<InstallLaunch> install(String path) async {
    paths.add(path);
    return result;
  }
}

UpdateRelease fakeRelease(
  String version, {
  String notes = 'Что нового: исправления',
}) =>
    UpdateRelease(
      version: version,
      parsed: AppVersion.tryParse(version)!,
      apkUrl: 'https://github.com/slavabars/soty/releases/download/x/a.apk',
      apkSize: 3,
      notes: notes,
    );

/// An update controller bound to [settings] whose APK target is [cache].
UpdateController updateController(
  ReleaseFeed feed,
  SettingsDao settings,
  Directory cache, {
  FakeInstaller? installer,
}) {
  return UpdateController(
    client: feed,
    settings: settings,
    installer: installer ?? FakeInstaller(),
    cacheDir: () async => cache,
  );
}
