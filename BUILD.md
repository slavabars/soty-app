# Soty — сборка, установка и запуск

**Русский** · [English](BUILD.en.md)

**Soty** («Соты») — serverless-мессенджер с end-to-end шифрованием для текста, голосовых заметок и фото. Он соединяет пиров напрямую: офлайн через mesh BLE / Wi-Fi Direct, онлайн через проверяемые потоки libp2p. Сервера и аккаунта нет.

| | |
|---|---|
| Application id | `ru.dcns.soty` |
| Android package / namespace | `ru.dcns.soty` |
| Dart package | `dtm_app` |
| Launcher label | Soty |

Этот файл — каноническое руководство по сборке, установке и запуску. Обязательные инженерные правила — в `AGENTS.md`; журнал аудита — в `docs/` (приватный, не публикуется).

## 1. Требования

- Flutter 3.32.3 / Dart 3.8.1 (`$HOME/development/flutter`).
- JDK 17. На этом хосте `/usr/lib/jvm/java-21-openjdk-amd64` — только JRE, поэтому `JAVA_HOME` надо явно указывать на 17.
- Android SDK в `~/Android/Sdk` (определяется автоматически) с NDK `27.0.12077973`, `platforms;android-36` и `build-tools;36.x`.
- Два AVD `android-36` для e2e (`Medium_Phone_API_36` и `Soty_B` уже созданы здесь) плюс KVM.

В каждом шелле, где идёт сборка, нужно экспортировать:

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
```

`--no-pub` используется для `analyze`/`test`, потому что зависимости зафиксированы.

## 2. Сборка

Самый быстрый путь — пересобрать все артефакты и прогнать проверки:

```bash
./scripts/build_all.sh
```

Он выполняет `pub get`, `analyze`, `test`, затем собирает два Android-канала и копирует их в `build-artifacts/`:

- `build-artifacts/soty-app-debug.apk` — debug, site flavor
- `build-artifacts/soty-release.apk` — **site** release, самообновляется из GitHub-релиза (сохраняет `REQUEST_INSTALL_PACKAGES`)
- `build-artifacts/soty-app-release.aab` — **play** bundle, обновления только через стор (без разрешения установки)

Отдельные сборки (flavor и define всегда должны совпадать):

```bash
flutter build apk --debug   --flavor site --dart-define=SOTY_CHANNEL=site
flutter build apk --release --flavor site --dart-define=SOTY_CHANNEL=site
flutter build appbundle --release --flavor play \
  --dart-define=SOTY_CHANNEL=play
flutter build linux --release                 # Linux x64 desktop bundle
```

Gradle валит сборку, если flavor и `SOTY_CHANNEL` расходятся, а `scripts/verify_channels.sh` перепроверяет полученные APK/AAB. Результаты:

- `build/app/outputs/flutter-apk/app-site-debug.apk`
- `build/app/outputs/flutter-apk/app-site-release.apk`
- `build/app/outputs/bundle/playRelease/app-play-release.aab`

`scripts/build_all.sh` покрывает только Android. Linux-бандл и его tar-архив собирает скрипт воркспейса, который владеет всеми артефактами:

```bash
cd ..
./scripts/build_apps.sh              # host + Android + device APKs + Linux
./scripts/build_apps.sh --skip-linux
```

- `build-artifacts/soty-linux-x64/` — запускаемый бандл (`./soty`)
- `build-artifacts/soty-linux-x64.tar.gz` — то же самое, упакованное для переноса

Версия в Settings → About берётся из `pubspec.yaml` и передаётся как `--dart-define=SOTY_APP_VERSION=`, поэтому экран не может расходиться с артефактом.

Артефакты попадают в `build/app/outputs/` (APK — в `flutter-apk/`, bundle — в `bundle/playRelease/`). `build/` и `build-artifacts/` в `.gitignore`.

> Release-сборки по умолчанию подписываются production upload-ключом (`~/.soty-keys/`, `SOTY_SIGNING=debug` отключает это); см. `../scripts/SIGNING.md`.

## 3. Установка

На подключённом устройстве или эмуляторе:

```bash
flutter install                       # ставит последнюю собранную release-сборку
adb install -r build-artifacts/soty-app-debug.apk
```

`flutter run` собирает, устанавливает и подключается за один шаг (используйте для разработки, чтобы работал hot reload):

```bash
flutter devices
flutter run -d <device-id>            # debug
flutter run -d <device-id> --release
```

Данные приложения лежат в приватном каталоге (`files/dtm.sqlite`, включая seeds); они переживают переустановку поверх, если не сделать `adb uninstall ru.dcns.soty`.

## 4. Emulator end-to-end (обязательно для изменений UI/транспорта)

BLE на эмуляторе недоступен, поэтому межdevice-проверка идёт через транспорт libp2p. `P2PTransport` слушает **фиксированный** порт (`p2pListenAddr = /ip4/0.0.0.0/tcp/4010`), поэтому до него можно достучаться через `adb forward`.

Для групп и общения между клиентами можно поднять **до пяти** эмуляторов одновременно. Каждый клиент обязан быть на **своём AVD**: `Medium_Phone_API_36`, `Soty_B`, `Soty_C`, `Soty_D`, `Soty_E` на портах `5554`, `5556`, `5558`, `5560`, `5562`. Два `-read-only` экземпляра одного AVD делят один записываемый userdata, поэтому оба получают **одну и ту же** строку `identity_entry` и **один и тот же** libp2p peer id — «второе устройство» на самом деле первое, и тест ничего не доказывает. Проверьте `android_id` у всех клиентов до того, как доверять прогону:

```bash
for p in 5554 5556 5558 5560 5562; do
  adb -s emulator-$p shell settings get secure android_id
done   # пять разных значений
```

Готовый harness (только запуск/остановка, без установки пакетов и без изменений роутера):

```bash
scripts/e2e-emulators.sh status
scripts/e2e-emulators.sh start 5 --create   # создаст Soty_C..E при необходимости
scripts/e2e-emulators.sh stop 5
```

Дальше базовый сценарий описан для двух клиентов (A/B); для группы добавьте C–E теми же шагами, каждому свой `adb forward` (например, `14703→4701`, `14704→4701`, `14705→4701`) и свой advertised multiaddr.

Создайте второй AVD один раз (`cmdline-tools` не нужны — скопируйте конфиг и дайте эмулятору создать свежий раздел данных):

```bash
cp ~/.android/avd/Medium_Phone.avd/config.ini ~/.android/avd/Soty_B.avd/config.ini
sed -i 's/^AvdId = .*/AvdId = Soty_B/' ~/.android/avd/Soty_B.avd/config.ini
sed -i 's/^avd.ini.displayname = .*/avd.ini.displayname = Soty B/' \
  ~/.android/avd/Soty_B.avd/config.ini
printf 'avd.ini.encoding=UTF-8\npath=%s\npath.rel=avd/Soty_B.avd\ntarget=android-36\n' \
  "$HOME/.android/avd/Soty_B.avd" > ~/.android/avd/Soty_B.ini
```

```bash
# Стабильность эмулятора на этом хосте: GPU-процесс может умереть через
# несколько минут ("bad color buffer handle", swiftshader bad_function_call)
# и утащить экземпляры с собой. Проверяйте `adb devices` перед каждым
# измерением, перезапускайте при необходимости и помните, что данные
# приложения переживают перезапуск.
EMU="$HOME/Android/Sdk/emulator/emulator"
$EMU -avd Medium_Phone_API_36 -port 5554 -no-window \
  -gpu swiftshader_indirect -no-snapshot -no-audio -no-boot-anim &
$EMU -avd Soty_B -port 5556 -no-window \
  -gpu swiftshader_indirect -no-snapshot -no-audio -no-boot-anim &
# Дополнительные клиенты: Soty_C 5558, Soty_D 5560, Soty_E 5562.
adb wait-for-device
adb -s emulator-5554 shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 3; done'
adb -s emulator-5556 shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 3; done'

# Пробросы хоста под advertised-адреса, которые зашиты в device APK
# (scripts/build_apps.sh: A — /ip4/10.0.2.2/tcp/5012, B — …/tcp/5011).
adb -s emulator-5554 forward tcp:5012 tcp:4010   # A доступен на 10.0.2.2:5012
adb -s emulator-5556 forward tcp:5011 tcp:4010   # B доступен на 10.0.2.2:5011

# Установить и запустить на обоих.
flutter build apk --debug --flavor site --dart-define=SOTY_CHANNEL=site \
  --dart-define=SOTY_DEV_HTTP=true
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-site-debug.apk
adb -s emulator-5556 install -r build/app/outputs/flutter-apk/app-site-debug.apk
adb -s emulator-5554 shell am start -n ru.dcns.soty/.MainActivity
adb -s emulator-5556 shell am start -n ru.dcns.soty/.MainActivity
adb -s emulator-5554 logcat -s flutter | grep -m1 'Soty p2p ready'
adb -s emulator-5556 logcat -s flutter | grep -m1 'Soty p2p ready'
```

На устройстве A разрешите запрос nearby-devices (идентичность создаётся по тапу «Continue» в онбординге; устройству B тоже нужен свой тап), откройте **Identity** и скопируйте invite, затем на A откройте **New chat** и введите X25519-ключ B, libp2p peer id и `/ip4/10.0.2.2/tcp/5011` (эмулятор достучится до loopback хоста по `10.0.2.2`). Отправьте сообщение, ответьте с B и убедитесь, что обе ветки свернулись в один диалог.

Групповой сценарий на 5 клиентах: A создаёт группу с B–E, каждый участник отправляет по сообщению, все пять видят один bubble на автора; F (не участник, если есть шестой AVD) не получает group-контейнер. Отдельно проверьте, что чек и media-slice не уходят не-участнику, а `q1` с чужим `conversationId` не отдаёт blob.

Debug-сборка открывает send-хук только на loopback и только при `--dart-define=SOTY_DEV_HTTP=true` (`lib/main.dart`). Без этого флага debug-APK не отдаёт seeds и не принимает debug-действия. Хук гоняет `MessengerController` точно так же, как composer — e2e использует его, чтобы отправлять без тапов по пикселям:

```bash
adb -s emulator-5554 forward tcp:14701 tcp:4701
adb -s emulator-5556 forward tcp:14702 tcp:4701   # чтобы управлять B из шелла
# импортировать пира с маршрутизацией (peer id + multiaddr)
curl -X POST -d '{"action":"import","pubKey":"<x25519-hex>",
  "edPubKey":"<ed25519-hex>","peerId":"<libp2p-peer-id>",
  "addrs":["/ip4/10.0.2.2/tcp/5011"],
  "displayName":"peer"}' http://127.0.0.1:14701/
# отправить, при желании — ответ с цитатой
curl -X POST -d '{"to":"<x25519-hex>","text":"hello"}' \
  http://127.0.0.1:14701/
curl -X POST -d '{"to":"<x25519-hex>","text":"re","quote":{"refId":"<hex>",
  "authorX":"<hex>","preview":"hello"}}' http://127.0.0.1:14701/
# seeds идентичности для офлайн-инструментов (живут в Keystore)
curl -X POST -d '{"action":"identity"}' http://127.0.0.1:14701/
```

Действие `identity` существует только в debug-сборках и только на loopback устройства. Его вызывает `tool/identity_probe.dart`; никогда не выносите его в release-сборку.

Backup-e2e использует ещё два debug-only действия: `{"action":"backupExport", "password":"…"}` возвращает запечатанный документ, а `{"action":"backupImport", "password":"…","backup":"…"}` восстанавливает его (заменяя существующую идентичность), чтобы очищенное устройство можно было восстановить из файла без навигации по пикеру хранилища. Оба вызывают тот же `BackupService`, что и экран настроек.

Статус исходящей доставки хранится по конвертам в таблице `message_statuses` (`id`, порядковый `status`, `updated_at`): `0` в очереди, `1` отправлено, `2` доставлено, `3` прочитано. Скачайте БД (ниже) и читайте таблицу, чтобы проверять жизненный цикл delivered/read, не полагаясь на пиксели чата.

Офлайн-проверка того, что реально легло на диск:

```bash
adb -s emulator-5554 exec-out run-as ru.dcns.soty cat files/dtm.sqlite \
  > /tmp/opencode/emu/a.sqlite
# Seeds идентичности живут в Android Keystore (строка SQLite хранит
# только публичные метаданные), поэтому сначала заберите их у debug dev-сервера:
adb -s emulator-5554 forward tcp:14701 tcp:4701
dart run tool/identity_probe.dart /tmp/opencode/emu/a 14701  # identity.json
dart run tool/peer_probe.dart /tmp/opencode/emu/a        # Ed/X keys + peerId
dart run tool/decrypt_stored.dart /tmp/opencode/emu/a    # verify + decrypt
```

`identity_probe` ходит в loopback dev-сервер, который поднимают только debug-сборки; `peer_probe` и `decrypt_stored` затем читают `identity.json` (для старых баз они всё ещё откатываются к колонкам seed). `peer_probe` печатает тот же peer id, что и runtime-лог; `decrypt_stored` должен расшифровать входящее сообщение ключом устройства и вывести его плейнтекст, но не должен суметь расшифровать сообщение, отправленное им самим. В `identity.json` приватные seeds: режим `600`, никогда не коммитить и не прикреплять.

Подводные камни UI-скриптинга: используйте `KEYCODE_TAB` для перемещения между полями диалога (IME сдвигает диалог и ломает захардкоженные тапы), `%s` для пробелов в `input text`, и заново снимайте bounds через `uiautomator` после открытия клавиатуры.

### 4.1 Media e2e (голосовые заметки + фото)

У composer есть кнопка **mic** (удерживать для записи) и кнопка **photo**. Обе управляются обычными жестами `adb input`; баннер записи показывает оставшиеся секунды, например `content-desc="Recording… 24 s left"`.

```bash
# Разрешения нужно выдавать заново на каждом свежем эмуляторе.
adb -s emulator-5554 shell pm grant ru.dcns.soty \
  android.permission.RECORD_AUDIO
adb -s emulator-5556 shell pm grant ru.dcns.soty \
  android.permission.RECORD_AUDIO

# Mic находится в [828,2190][933,2295]; зажмите и отпустите.
adb -s emulator-5554 shell input swipe 880 2242 880 2242 6000

# Отменить запись вместо отправки (см. ограничение ниже).
adb -s emulator-5554 shell input motionevent CANCEL 880 2242

# Слишком большое фото не должно отправляться вообще: приложение покажет
# "Photo is too large (max 128 KB)", а число строк media_blobs не изменится.
adb -s emulator-5554 shell 'run-as ru.dcns.soty sqlite3 files/dtm.sqlite \
  "select count(*) from media_blobs"'
```

Чтобы подсунуть файл системному пикеру фото, залейте его и просканируйте. `content call --method scan_volume` оставляет `is_pending=1`, и пикер ничего не показывает, поэтому сканируйте сам файл:

```bash
adb -s emulator-5554 push photo_big.png /sdcard/Pictures/photo_big.png
adb -s emulator-5554 shell am broadcast -a \
  android.intent.action.MEDIA_SCANNER_SCAN_FILE \
  -d file:///sdcard/Pictures/photo_big.png
```

**Ограничение — кнопку X на баннере нельзя нажать через `adb`.** `adb shell input` всегда переиспользует pointer id 0, поэтому второй жест завершает первый как UP (что **отправляет** запись), а запись в `/dev/input` напрямую запрещена (`sendevent: Permission denied`; `adbd cannot run as root in production builds`). Проверяйте отмену через `input motionevent CANCEL`, а кнопку X покрывайте widget-тестом.

## 5. Тесты и анализ

```bash
flutter analyze --no-pub          # должен вывести: No issues found
flutter test --no-pub             # unit + integration, всё зелёное
flutter test --no-pub test/integration/p2p_transport_test.dart
```

`test/integration/p2p_transport_test.dart` поднимает два настоящих libp2p-хоста на не-loopback интерфейсе; эмуляция mesh живёт в `test/integration/mesh_emulation_test.dart`.

## 6. Иконки

Все иконки генерируются из кода — не редактируйте PNG вручную:

```bash
python3 tool/generate_icons.py
```

Он перезаписывает Android legacy + adaptive-foreground mipmap, web-иконки и наборы iOS/macOS/Windows из медовой соты (гексагональная ячейка, соединённая с соседями) на градиенте teal→indigo.

## 7. Поддержка платформ (этот Linux-хост)

| Платформа | Статус |
|---|---|
| Android (apk, aab) | собирается |
| Web | не собирается — `dart:ffi`/drift/sqlite3 и нет web-бэкенда транспорта |
| Linux desktop | собирается — cmake, ninja, clang и GTK 3.24 dev установлены |
| iOS / macOS / Windows | не кросс-компилируются с Linux |

Причины несобираемости продублированы в начале `scripts/build_all.sh`; не повторяйте попытки без нового тулинга. Linux-релиз собирается из `../scripts/build_apps.sh`, потому что именно там собирается `build-artifacts/`.

Linux-бандл линкует `audioplayers_linux`, которому нужны **dev**-заголовки gstreamer (`-lgstapp-1.0 -lgstbase-1.0 -lgstreamer-1.0`). Без sudo они распаковываются в локальный префикс (`../.build-deps/gstprefix`), и `../scripts/build_apps.sh` экспортирует для него `PKG_CONFIG_PATH` и `LIBRARY_PATH`, когда префикс существует. Runtime-библиотеки установлены системно, поэтому поставленный бандл работает на обычной системе.
