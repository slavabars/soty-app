# Soty — приложение

**Русский** · [English](README.en.md)

[![CI](https://github.com/slavabars/soty-app/actions/workflows/ci.yml/badge.svg)](https://github.com/slavabars/soty-app/actions/workflows/ci.yml) [![Nightly](https://github.com/slavabars/soty-app/actions/workflows/nightly.yml/badge.svg)](https://github.com/slavabars/soty-app/actions/workflows/nightly.yml) [![License: AGPL-3.0](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE) [![Latest release](https://img.shields.io/github/v/release/slavabars/soty?label=latest)](https://github.com/slavabars/soty/releases)

Клиент Soty для Android, Linux и macOS. Serverless, end-to-end зашифрованный мессенджер: офлайн — mesh (BLE / Wi-Fi Direct), онлайн — libp2p. Аккаунтов и центрального сервера нет, релеи хранят только зашифрованные конверты.

Этот репозиторий — исходники клиента. Релизы, установка релея и описание проекта: https://github.com/slavabars/soty. Код релея: https://github.com/slavabars/soty-relay.

## Сборка

Требуется Flutter 3.32.3 / Dart 3.8.1, JDK 17 и Android SDK (для Android).

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

flutter pub get
flutter analyze --no-pub
flutter test --no-pub

# debug APK
SOTY_SIGNING=debug flutter build apk --debug --flavor site
```

Drift и `json_serializable` генерируются:

```bash
dart run build_runner build
```

Подпись релизов описана в основном репозитории. Официальные сборки — только из [Releases](https://github.com/slavabars/soty/releases).

## Безопасность

- Модель угроз: [`docs/threat_model.md`](docs/threat_model.md).
- Как сообщить об уязвимости: [`SECURITY.md`](SECURITY.md) — **не** через публичный issue.
- Лимиты и порядок обработки конвертов: `lib/core/security_limits.dart`.

## Участие

Правила и порядок работы: [`CONTRIBUTING.md`](CONTRIBUTING.md), [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## Лицензия

AGPL-3.0, см. [`LICENSE`](LICENSE) и [`NOTICE`](NOTICE). Название и логотип «Soty / Соты» лицензией не покрываются.
