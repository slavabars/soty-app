#!/usr/bin/env bash
# Regenerates all buildable DTM app deliverables into the workspace
# build-artifacts/ (one level above this repo):
#   <workspace>/build-artifacts
# The workspace scripts/build_apps.sh drives this as its keep-step and adds
# dtm_host + device e2e APKs to the same directory.
#
# Note on platforms:
#   android (apk + appbundle)  — buildable here (NDK 27, JDK 17)
#   web                        — NOT buildable: drift/sqlite3 require dart:ffi,
#                                and the mesh/libp2p transports have no web
#                                backend
#   linux desktop              — buildable here (cmake/ninja/clang/GTK 3.24
#                                are installed); built by the workspace script
#                                scripts/build_apps.sh, which owns the Linux
#                                bundle + tarball artifacts
#   ios/macos/windows          — not cross-compiled from Linux (Flutter cannot
#                                cross-compile those from a Linux host)
set -euo pipefail

# Flutter SDK — java-21 on this host is JRE-only, so use the full JDK 17.
export PATH="$HOME/development/flutter/bin:$PATH"
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
OUT="$(cd "$ROOT/.." && pwd)/build-artifacts"

# Версия из pubspec, вшивается в релизные сборки (Settings → About).
SOTY_VERSION="$(awk '/^version:/{print $2; exit}' pubspec.yaml)"
[ -n "$SOTY_VERSION" ] || { echo "не нашёл version: в pubspec.yaml"; exit 2; }

flutter pub get

echo "== analyze =="
flutter analyze --no-pub

echo "== tests =="
flutter test --no-pub

echo "== android: debug apk (site) =="
flutter build apk --debug --flavor site --dart-define=SOTY_CHANNEL=site

echo "== android: release apk (site, self-updating) =="
flutter build apk --release --flavor site \
  --dart-define=SOTY_CHANNEL=site \
  --dart-define=SOTY_APP_VERSION="$SOTY_VERSION"

echo "== android: app bundle (play, no APK installer) =="
# The NDK symbol-strip step may exit nonzero on this host; the .aab is still
# written, so keep the build if the artifact appeared.
flutter build appbundle --release --flavor play \
  --dart-define=SOTY_CHANNEL=play \
  --dart-define=SOTY_APP_VERSION="$SOTY_VERSION" || {
  echo "WARN: appbundle reported a strip error; checking for artifact..."
  [ -f build/app/outputs/bundle/playRelease/app-play-release.aab ] || exit 1
}

mkdir -p "$OUT"
cp build/app/outputs/flutter-apk/app-site-debug.apk "$OUT/soty-app-debug.apk"
cp build/app/outputs/flutter-apk/app-site-release.apk "$OUT/soty-release.apk"
cp build/app/outputs/bundle/playRelease/app-play-release.aab \
  "$OUT/soty-app-release.aab"

echo
echo "Artifacts in $OUT:"
ls -la "$OUT"