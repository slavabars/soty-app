import 'dart:io' show Platform;

/// Distribution channel this binary was built for.
///
/// `site` — the APK published on soty.su: it updates itself from GitHub.
/// `play` — the bundle uploaded to Google Play: updates come from the store
/// only, and the APK updater (with `REQUEST_INSTALL_PACKAGES`) is removed
/// from the manifest by the `play` flavor.
const String kSotyChannel =
    String.fromEnvironment('SOTY_CHANNEL', defaultValue: 'site');

/// The Play build never downloads or installs APK files itself.
const bool kPlayBuild = kSotyChannel == 'play';

/// Whether self-updating from the GitHub release feed is allowed.
///
/// Only Android builds outside Play: a desktop build has no APK to install,
/// and Play forbids apps that update themselves.
bool selfUpdateEnabled({required String channel, required bool isAndroid}) =>
    channel != 'play' && isAndroid;

bool get kSelfUpdate => selfUpdateEnabled(
      channel: kSotyChannel,
      isAndroid: Platform.isAndroid,
    );
