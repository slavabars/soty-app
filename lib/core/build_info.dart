/// Build identity of the app, shown in Settings → About.
///
/// The version is injected by `scripts/build_apps.sh` from `pubspec.yaml`
/// (`--dart-define=SOTY_APP_VERSION=...`) so the screen can never drift from
/// what was actually built; the literal below is the fallback for plain
/// `flutter run` builds.
library;

/// `major.minor.patch+build`, e.g. `1.1.0+2`.
const String kSotyVersion = String.fromEnvironment(
  'SOTY_APP_VERSION',
  defaultValue: '1.7.21+39',
);

/// Public binaries+docs mirror. The source of truth is a private workspace
/// repository, so this is the only git link that can be put in front of users.
const String kSotyGitUrl = 'https://github.com/slavabars/soty';

/// Version without the build number, for one-line footers.
String get kSotyVersionName => kSotyVersion.split('+').first;
