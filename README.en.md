# Soty — the app

[Русский](README.md) · **English**

[![CI](https://github.com/slavabars/soty-app/actions/workflows/ci.yml/badge.svg)](https://github.com/slavabars/soty-app/actions/workflows/ci.yml) [![Nightly](https://github.com/slavabars/soty-app/actions/workflows/nightly.yml/badge.svg)](https://github.com/slavabars/soty-app/actions/workflows/nightly.yml) [![License: AGPL-3.0](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE) [![Latest release](https://img.shields.io/github/v/release/slavabars/soty?label=latest)](https://github.com/slavabars/soty/releases)

The Soty client for Android, Linux and macOS. A serverless, end-to-end encrypted messenger: offline over a mesh (BLE / Wi-Fi Direct), online over libp2p. There are no accounts and no central server; relays store encrypted envelopes only.

This repository is the client source. Releases, relay install and the project overview: https://github.com/slavabars/soty. Relay source: https://github.com/slavabars/soty-relay.

## Build

You need Flutter 3.32.3 / Dart 3.8.1, JDK 17 and the Android SDK (for Android).

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

flutter pub get
flutter analyze --no-pub
flutter test --no-pub

# debug APK
SOTY_SIGNING=debug flutter build apk --debug --flavor site
```

Drift and `json_serializable` are generated:

```bash
dart run build_runner build
```

Release signing is described in the main repository. Official builds come only from [Releases](https://github.com/slavabars/soty/releases).

## Security

- Threat model: [`docs/threat_model.md`](docs/threat_model.md).
- How to report a vulnerability: [`SECURITY.md`](SECURITY.md) — **not** through a public issue.
- Limits and the envelope pipeline: `lib/core/security_limits.dart`.

## Contributing

The rules and workflow are in [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## License

AGPL-3.0, see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE). The "Soty / Соты" name and logo are not covered by the license.
