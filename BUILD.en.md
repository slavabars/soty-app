# Soty — build, install & run

[Русский](BUILD.md) · **English**

**Soty** («Соты») is a serverless, end-to-end encrypted messenger for text, voice notes and photos. It reaches peers directly over an offline BLE / Wi-Fi Direct mesh and over verifiable libp2p streams when online. There is no server and no account.

| | |
|---|---|
| Application id | `ru.dcns.soty` |
| Android package / namespace | `ru.dcns.soty` |
| Dart package | `dtm_app` |
| Launcher label | Soty |

This file is the canonical build/install/run guide. `AGENTS.md` holds the binding engineering rules; `docs/` holds the private audit log.

## 1. Requirements

- Flutter 3.32.3 / Dart 3.8.1 (`$HOME/development/flutter`).
- JDK 17. On this host `/usr/lib/jvm/java-21-openjdk-amd64` is a JRE-only install, so point `JAVA_HOME` at 17 explicitly.
- Android SDK at `~/Android/Sdk` (auto-detected) with NDK `27.0.12077973`, `platforms;android-36` and `build-tools;36.x`.
- Two `android-36` AVDs for the e2e (`Medium_Phone_API_36` and `Soty_B` are pre-created here) plus KVM.

Every shell that builds must export:

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
```

`--no-pub` is used for `analyze`/`test` because dependencies are locked.

## 2. Build

Fastest path — regenerate all deliverables and run the checks:

```bash
./scripts/build_all.sh
```

This runs `pub get`, `analyze`, `test`, then builds the two Android channels and copies them to `build-artifacts/`:

- `build-artifacts/soty-app-debug.apk` — debug, site flavor
- `build-artifacts/soty-release.apk` — **site** release, self-updating from the GitHub release (keeps `REQUEST_INSTALL_PACKAGES`)
- `build-artifacts/soty-app-release.aab` — **play** bundle, store updates only (no installer permission)

Individual builds (the flavor and the define must always match):

```bash
flutter build apk --debug   --flavor site --dart-define=SOTY_CHANNEL=site
flutter build apk --release --flavor site --dart-define=SOTY_CHANNEL=site
flutter build appbundle --release --flavor play \
  --dart-define=SOTY_CHANNEL=play
flutter build linux --release                 # Linux x64 desktop bundle
```

Gradle fails the build when the flavor and `SOTY_CHANNEL` disagree, and `scripts/verify_channels.sh` re-checks the produced APK/AAB. Outputs:

- `build/app/outputs/flutter-apk/app-site-debug.apk`
- `build/app/outputs/flutter-apk/app-site-release.apk`
- `build/app/outputs/bundle/playRelease/app-play-release.aab`

`scripts/build_all.sh` covers Android only. The Linux bundle and its tarball are produced by the workspace script, which owns every artifact:

```bash
cd ..
./scripts/build_apps.sh              # host + Android + device APKs + Linux
./scripts/build_apps.sh --skip-linux
```

- `build-artifacts/soty-linux-x64/` — runnable bundle (`./soty`)
- `build-artifacts/soty-linux-x64.tar.gz` — the same, packed for transfer

The version shown in Settings → About is taken from `pubspec.yaml` and passed in as `--dart-define=SOTY_APP_VERSION=`, so the screen can never disagree with the artifact.

Artifacts land under `build/app/outputs/` (APKs in `flutter-apk/`, the bundle in `bundle/playRelease/`). `build/` and `build-artifacts/` are gitignored.

> Release builds are signed with the production upload key by default (`~/.soty-keys/`, `SOTY_SIGNING=debug` opts out); see `../scripts/SIGNING.md`.

## 3. Install

On a connected device or emulator:

```bash
flutter install                       # installs the last built release
adb install -r build-artifacts/soty-app-debug.apk
```

`flutter run` builds, installs and attaches in one step (use it for development so hot reload works):

```bash
flutter devices
flutter run -d <device-id>            # debug
flutter run -d <device-id> --release
```

App data lives in the app-private dir (`files/dtm.sqlite`, seeds included); it survives reinstall-over unless you `adb uninstall ru.dcns.soty`.

## 4. Emulator end-to-end (mandatory for UI/transport changes)

BLE is not available on the emulator, so cross-device verification uses the libp2p transport. `P2PTransport` listens on a **fixed** port (`p2pListenAddr = /ip4/0.0.0.0/tcp/4010`) so it can be reached via `adb forward`.

The two emulators must be **two different AVDs**. Two `-read-only` instances of one AVD share a single writable userdata image here, so both get the *same* `identity_entry` row and the *same* libp2p peer id — the "second device" is really the first one, and the test proves nothing. Check it before trusting a run:

```bash
adb -s emulator-5554 shell settings get secure android_id
adb -s emulator-5556 shell settings get secure android_id   # must differ
```

Create the second AVD once (no `cmdline-tools` needed — copy the config and let the emulator build a fresh data partition):

```bash
cp ~/.android/avd/Medium_Phone.avd/config.ini ~/.android/avd/Soty_B.avd/config.ini
sed -i 's/^AvdId = .*/AvdId = Soty_B/' ~/.android/avd/Soty_B.avd/config.ini
sed -i 's/^avd.ini.displayname = .*/avd.ini.displayname = Soty B/' \
  ~/.android/avd/Soty_B.avd/config.ini
printf 'avd.ini.encoding=UTF-8\npath=%s\npath.rel=avd/Soty_B.avd\ntarget=android-36\n' \
  "$HOME/.android/avd/Soty_B.avd" > ~/.android/avd/Soty_B.ini
```

```bash
# Emulator stability on this host: the GPU process can die after several
# minutes ("bad color buffer handle", swiftshader bad_function_call) and take
# the instances with it. Check `adb devices` before each measurement, relaunch
# if needed, and remember app data persists across a relaunch.
EMU="$HOME/Android/Sdk/emulator/emulator"
$EMU -avd Medium_Phone_API_36 -port 5554 -no-window \
  -gpu swiftshader_indirect -no-snapshot -no-audio -no-boot-anim &
$EMU -avd Soty_B -port 5556 -no-window \
  -gpu swiftshader_indirect -no-snapshot -no-audio -no-boot-anim &
adb wait-for-device
adb -s emulator-5554 shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 3; done'
adb -s emulator-5556 shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 3; done'

# Host forwards matching the advertised addresses the device APKs bake in
# (scripts/build_apps.sh: A is /ip4/10.0.2.2/tcp/5012, B is …/tcp/5011).
adb -s emulator-5554 forward tcp:5012 tcp:4010   # A reachable at 10.0.2.2:5012
adb -s emulator-5556 forward tcp:5011 tcp:4010   # B reachable at 10.0.2.2:5011

# Install and launch on both.
flutter build apk --debug --flavor site --dart-define=SOTY_CHANNEL=site
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-site-debug.apk
adb -s emulator-5556 install -r build/app/outputs/flutter-apk/app-site-debug.apk
adb -s emulator-5554 shell am start -n ru.dcns.soty/.MainActivity
adb -s emulator-5556 shell am start -n ru.dcns.soty/.MainActivity
adb -s emulator-5554 logcat -s flutter | grep -m1 'Soty p2p ready'
adb -s emulator-5556 logcat -s flutter | grep -m1 'Soty p2p ready'
```

On device A, grant the nearby-devices prompt (the onboarding "Continue" tap is what creates the identity; device B also needs its own Continue tap), open **Identity** and copy the invite, then on A open **New chat** and enter B's X25519 key, libp2p peer id and `/ip4/10.0.2.2/tcp/5011` (the emulator reaches the host loopback at `10.0.2.2`). Send a message, reply from B, and confirm both threads fold into one conversation.

A debug build also exposes a loopback-only send hook (`lib/main.dart`, `kDebugMode`), which drives `MessengerController` exactly as the composer does — the e2e uses it to send without tapping pixels:

```bash
adb -s emulator-5554 forward tcp:14701 tcp:4701
adb -s emulator-5556 forward tcp:14702 tcp:4701   # to drive B from the shell
# import a peer with routing (peer id + multiaddr)
curl -X POST -d '{"action":"import","pubKey":"<x25519-hex>",
  "edPubKey":"<ed25519-hex>","peerId":"<libp2p-peer-id>",
  "addrs":["/ip4/10.0.2.2/tcp/5011"],
  "displayName":"peer"}' http://127.0.0.1:14701/
# send, optionally as a reply carrying a quote
curl -X POST -d '{"to":"<x25519-hex>","text":"hello"}' \
  http://127.0.0.1:14701/
curl -X POST -d '{"to":"<x25519-hex>","text":"re","quote":{"refId":"<hex>",
  "authorX":"<hex>","preview":"hello"}}' http://127.0.0.1:14701/
# identity seeds for the offline tools (they live in the Keystore)
curl -X POST -d '{"action":"identity"}' http://127.0.0.1:14701/
```

The `identity` action exists only in debug builds and only on the device loopback. It is what `tool/identity_probe.dart` calls; never expose it in a release build.

Backup e2e uses two more debug-only actions: `{"action":"backupExport", "password":"…"}` returns the sealed document, and `{"action":"backupImport", "password":"…","backup":"…"}` restores it (replacing an existing identity) so a wiped device can be rebuilt from a file without navigating the storage picker. Both call the same `BackupService` the Settings screen uses.

Outgoing delivery status is stored per envelope in the `message_statuses` table (`id`, `status` ordinal, `updated_at`): `0` queued, `1` sent, `2` delivered, `3` read. Pull the DB (below) and read that table to check the delivered/read lifecycle without relying on the chat pixels.

Offline verification of what actually landed on disk:

```bash
adb -s emulator-5554 exec-out run-as ru.dcns.soty cat files/dtm.sqlite \
  > /tmp/opencode/emu/a.sqlite
# The identity seeds live in the Android Keystore since the keystore migration (the SQLite row
# keeps only public metadata), so fetch them from the debug dev server first:
adb -s emulator-5554 forward tcp:14701 tcp:4701
dart run tool/identity_probe.dart /tmp/opencode/emu/a 14701  # identity.json
dart run tool/peer_probe.dart /tmp/opencode/emu/a        # Ed/X keys + peerId
dart run tool/decrypt_stored.dart /tmp/opencode/emu/a    # verify + decrypt
```

`identity_probe` talks to the loopback dev server that only debug builds start; `peer_probe` and `decrypt_stored` then read `identity.json` (they still fall back to the seed columns for older databases). `peer_probe` prints the same peer id that the runtime log shows; `decrypt_stored` must decrypt the inbound message with the device key and print its plaintext, and must not be able to decrypt the message it sent itself. `identity.json` contains private seeds: mode `600`, never commit or attach it.

UI scripting gotchas: use `KEYCODE_TAB` to move between dialog fields (the IME shifts the dialog and breaks hard-coded taps), `%s` for spaces in `input text`, and re-dump `uiautomator` bounds after the keyboard opens.

### 4.1 Media e2e (voice notes + photos)

The composer owns a **mic** button (hold to record) and a **photo** button. Both are driven with plain `adb input` gestures; the recording banner shows the remaining seconds, e.g. `content-desc="Recording… 24 s left"`.

```bash
# Permissions must be re-granted on every fresh emulator.
adb -s emulator-5554 shell pm grant ru.dcns.soty \
  android.permission.RECORD_AUDIO
adb -s emulator-5556 shell pm grant ru.dcns.soty \
  android.permission.RECORD_AUDIO

# Mic is at [828,2190][933,2295]; press and hold it, then release.
adb -s emulator-5554 shell input swipe 880 2242 880 2242 6000

# Cancel a take instead of sending it (see the limitation below).
adb -s emulator-5554 shell input motionevent CANCEL 880 2242

# A photo that is too large must not be sent at all: the app shows
# "Photo is too large (max 128 KB)" and the media_blobs row count stays.
adb -s emulator-5554 shell 'run-as ru.dcns.soty sqlite3 files/dtm.sqlite \
  "select count(*) from media_blobs"'
```

To feed the system photo picker, push the file and scan it. `content call --method scan_volume` leaves `is_pending=1` and the picker then shows nothing, so scan the file itself:

```bash
adb -s emulator-5554 push photo_big.png /sdcard/Pictures/photo_big.png
adb -s emulator-5554 shell am broadcast -a \
  android.intent.action.MEDIA_SCANNER_SCAN_FILE \
  -d file:///sdcard/Pictures/photo_big.png
```

**Limitation — the banner's X button cannot be tapped through `adb`.** `adb shell input` always reuses pointer id 0, so a second gesture ends the first one as an UP (which *sends* the take), and writing to `/dev/input` directly is denied (`sendevent: Permission denied`; `adbd cannot run as root in production builds`). Verify the cancel path with `input motionevent CANCEL` instead, and cover the X button with a widget test.

## 5. Tests and analysis

```bash
flutter analyze --no-pub          # must report: No issues found
flutter test --no-pub             # unit + integration, all green
flutter test --no-pub test/integration/p2p_transport_test.dart
```

`test/integration/p2p_transport_test.dart` starts two real libp2p hosts on a non-loopback interface; the mesh emulation lives in `test/integration/mesh_emulation_test.dart`.

## 6. Icons

All icons are generated from code — do not edit the PNGs by hand:

```bash
python3 tool/generate_icons.py
```

It rewrites Android legacy + adaptive-foreground mipmaps, web icons, and the iOS/macOS/Windows icon sets from the honeycomb mark (a hex cell wired to its neighbours) on a teal-to-indigo gradient.

## 7. Platform support (this Linux host)

| Platform | Status |
|---|---|
| Android (apk, aab) | buildable |
| Web | not buildable — `dart:ffi`/drift/sqlite3 and no web transport backend |
| Linux desktop | buildable — cmake, ninja, clang and GTK 3.24 dev are installed |
| iOS / macOS / Windows | not cross-compiled from Linux |

The non-buildable reasons are duplicated at the top of `scripts/build_all.sh`; do not retry them without new tooling. The Linux release is driven from `../scripts/build_apps.sh`, since that is where `build-artifacts/` is assembled.

The Linux bundle links `audioplayers_linux`, which needs the gstreamer **dev** headers (`-lgstapp-1.0 -lgstbase-1.0 -lgstreamer-1.0`). Without sudo they are extracted into a local prefix (`../.build-deps/gstprefix`), and `../scripts/build_apps.sh` exports `PKG_CONFIG_PATH` and `LIBRARY_PATH` for it when the prefix exists. The runtime libraries are installed system-wide, so the shipped bundle runs on a plain system.
