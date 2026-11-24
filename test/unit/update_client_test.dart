import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:dtm_app/core/build_info.dart';
import 'package:dtm_app/core/crypto/hex.dart' show bytesToHex;
import 'package:dtm_app/core/security_limits.dart';
import 'package:dtm_app/core/update/update_client.dart';
import 'package:dtm_app/core/update/version_compare.dart';
import 'package:flutter_test/flutter_test.dart';

String _payload({
  String tag = 'v1.4.0+11',
  Object? assets,
  Object? body = 'Что нового',
  Map<String, Object?> extra = const {},
}) {
  return jsonEncode({
    'tag_name': tag,
    'assets': assets ??
        [
          {
            'name': 'soty-release.apk',
            'browser_download_url':
                'https://github.com/slavabars/soty/releases/download/'
                    'v1.4.0+11/soty-release.apk',
            'size': 12345678,
          },
        ],
    'body': body,
    ...extra,
  });
}

const _apkSum =
    '62f0e2e0c4a2400c3e39cb19644364289e6f6f30b5d9f4e3ce6cbb6dac3f9fb5';
const _tarSum =
    '1203f736c56b76266edd041a236376294568c68bc852d469d25194285b2cf5d9';

String _notesWithSum(String sum, {String asset = 'soty-release.apk'}) => """
## Файлы

| Файл | Что это | SHA-256 |
| --- | --- | --- |
| `dtm_host.bin` | relay | `13cf02e646514ad615f1b4892191f0cc9b67fc73938c79e132e272ad084c8703` |
| `$asset` | Android-приложение | `$sum` |
""";

void main() {
  group('UpdateClient.parseRelease', () {
    test('reads the tag, apk asset, size and notes', () {
      final release = UpdateClient.parseRelease(_payload());
      expect(release, isNotNull);
      expect(release!.version, '1.4.0+11');
      expect(release.parsed, const AppVersion(1, 4, 0, 11));
      expect(release.apkSize, 12345678);
      expect(release.notes, 'Что нового');
      expect(release.apkUrl, startsWith('https://github.com/'));
    });

    test('prefers the release apk over another apk asset', () {
      final release = UpdateClient.parseRelease(
        _payload(
          assets: [
            {
              'name': 'soty-app-debug.apk',
              'browser_download_url':
                  'https://github.com/slavabars/soty/releases/download/x/d.apk',
              'size': 1,
            },
            {
              'name': 'soty-release.apk',
              'browser_download_url':
                  'https://github.com/slavabars/soty/releases/download/x/r.apk',
              'size': 2,
            },
          ],
        ),
      );
      expect(release!.apkUrl, endsWith('r.apk'));
      expect(release.apkSize, 2);
    });

    test('falls back to any apk asset', () {
      final release = UpdateClient.parseRelease(
        _payload(
          assets: [
            {
              'name': 'SOTY-1.4.0.APK',
              'browser_download_url':
                  'https://objects.githubusercontent.com/x/soty.apk',
              'size': 3,
            },
          ],
        ),
      );
      expect(release, isNotNull);
      expect(release!.apkSize, 3);
    });

    test('rejects a feed with nothing installable', () {
      for (final raw in <String>[
        'not json at all',
        '[]',
        '"string"',
        'null',
        jsonEncode({'assets': <Object>[]}),
        _payload(tag: 'not-a-version'),
        _payload(tag: 'v1.4'),
        _payload(assets: 'nope'),
        _payload(assets: <Object>[]),
        _payload(
          assets: [
            {
              'name': 'notes.txt',
              'browser_download_url': 'https://github.com/x/notes.txt',
              'size': 1,
            },
          ],
        ),
        _payload(
          assets: [
            {
              'name': 'soty.apk',
              'browser_download_url': 'http://github.com/x/soty.apk',
              'size': 1,
            },
          ],
        ),
        _payload(
          assets: [
            {
              'name': 'soty.apk',
              'browser_download_url': 'https://evil.example/soty.apk',
              'size': 1,
            },
          ],
        ),
        _payload(
          assets: [
            {
              'name': 'soty.apk',
              'browser_download_url':
                  'https://github.com/'
                      '${'a' * maxUpdateAssetUrlLength}/soty.apk',
              'size': 1,
            },
          ],
        ),
        _payload(
          assets: [
            {'name': 5, 'browser_download_url': 'https://github.com/a.apk'},
          ],
        ),
      ]) {
        expect(UpdateClient.parseRelease(raw), isNull, reason: raw);
      }
    });

    test('a bad size is reported as unknown, never negative', () {
      for (final size in <Object?>[null, -1, 'big', 0, 1 << 40]) {
        final release = UpdateClient.parseRelease(
          _payload(
            assets: [
              {
                'name': 'soty-release.apk',
                'browser_download_url': 'https://github.com/a.apk',
                'size': size,
              },
            ],
          ),
        );
        expect(release!.apkSize, 0, reason: '$size');
      }
    });

    test('notes are truncated to the display bound', () {
      final release = UpdateClient.parseRelease(
        _payload(body: 'x' * (maxUpdateNotesChars + 500)),
      );
      expect(release!.notes.length, maxUpdateNotesChars);
    });

    test('non-string notes are dropped', () {
      final release = UpdateClient.parseRelease(_payload(body: 42));
      expect(release!.notes, isEmpty);
    });

    test('reads the APK sha256 out of the notes file table', () {
      final release = UpdateClient.parseRelease(
        _payload(body: _notesWithSum(_apkSum)),
      );
      expect(release!.apkSha256, _apkSum);
    });

    test('a digest written past the notes excerpt is still found', () {
      final body = '${'x' * (maxUpdateNotesChars + 100)}\n'
          '${_notesWithSum(_tarSum)}';
      final release = UpdateClient.parseRelease(_payload(body: body));
      expect(release!.notes.length, maxUpdateNotesChars);
      expect(
        release.apkSha256,
        _tarSum,
        reason: 'the table follows the excerpt',
      );
    });

    test('an uppercase digest is normalised to lowercase', () {
      final release = UpdateClient.parseRelease(
        _payload(body: _notesWithSum(_apkSum.toUpperCase())),
      );
      expect(release!.apkSha256, _apkSum);
    });

    test('no digest, a malformed digest or another asset never matches', () {
      expect(
        UpdateClient.parseRelease(_payload(body: 'Что нового'))!.apkSha256,
        isNull,
      );
      for (final body in <String>[
        _notesWithSum('not-a-digest'),
        _notesWithSum('a' * 63),
        _notesWithSum(_apkSum, asset: 'soty-app-release.aab'),
      ]) {
        expect(
          UpdateClient.parseRelease(_payload(body: body))!.apkSha256,
          isNull,
          reason: body,
        );
      }
      // A hash mentioned in prose is not a file-table row for this asset.
      expect(
        UpdateClient.parseRelease(
          _payload(body: 'SHA-256 `$_apkSum`'),
        )!.apkSha256,
        isNull,
      );
    });
  });

  group('UpdateRelease json', () {
    test('round-trips the stored subset', () {
      final release = UpdateClient.parseRelease(_payload())!;
      final restored = UpdateRelease.fromJson(release.toJson());
      expect(restored, isNotNull);
      expect(restored!.version, release.version);
      expect(restored.parsed, release.parsed);
      expect(restored.apkUrl, release.apkUrl);
      expect(restored.apkSize, release.apkSize);
      expect(restored.notes, release.notes);
      expect(restored.apkSha256, release.apkSha256);
    });

    test('rejects corrupt or untrusted stored values', () {
      final good = jsonDecode(
        UpdateClient.parseRelease(_payload())!.toJson(),
      ) as Map<String, dynamic>;
      Map<String, dynamic> withValue(String key, Object? value) =>
          {...good, key: value};
      for (final raw in <String>[
        '',
        'nope',
        '[]',
        '{"version":"1.4.0+11"}',
        jsonEncode(withValue('version', 11)),
        jsonEncode(withValue('version', 'not-a-version')),
        jsonEncode(withValue('apkUrl', 'http://github.com/a.apk')),
        jsonEncode(withValue('apkUrl', 'https://evil.example/a.apk')),
        jsonEncode(withValue('notes', 7)),
        jsonEncode(withValue('apkSha256', 'not-a-digest')),
        jsonEncode(withValue('apkSha256', 7)),
        jsonEncode(withValue('notes', 'x' * (maxUpdateNotesChars + 1))),
        'x' * (maxUpdateMetadataBytes + 1),
      ]) {
        expect(UpdateRelease.fromJson(raw), isNull, reason: raw);
      }
    });
  });

  group('UpdateClient over HTTP', () {
    late HttpServer server;
    late Uri url;

    tearDown(() async {
      await server.close(force: true);
    });

    Future<void> serve(
      Future<void> Function(HttpRequest request) handler,
    ) async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      url = Uri.parse('http://127.0.0.1:${server.port}/latest');
      server.listen((request) async {
        await handler(request);
      });
    }

    test('a well-formed answer yields the release', () async {
      await serve((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(_payload());
        await request.response.close();
      });
      final client = UpdateClient(
        currentVersion: '1.3.0+10',
        releaseUrl: url,
      );
      final release = await client.fetchLatest();
      expect(release, isNotNull);
      expect(release!.version, '1.4.0+11');
    });

    test('tag notes are read from the release body', () async {
      await serve((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'body': '## Что нового\n- fix'}));
        await request.response.close();
      });
      final client = UpdateClient(
        currentVersion: '1.3.0+10',
        releaseUrl: url,
      );
      final notes = await client.fetchTagNotes(kSotyVersion);
      expect(notes, '## Что нового\n- fix');
      expect(server.port, greaterThan(0));
    });

    test('a missing tag or bad body yields null notes', () async {
      await serve((request) async {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
      final client = UpdateClient(
        currentVersion: '1.3.0+10',
        releaseUrl: url,
      );
      expect(await client.fetchTagNotes(kSotyVersion), isNull);
      expect(UpdateClient.parseNotes('not json'), isNull);
      expect(UpdateClient.parseNotes('{"body": 5}'), isNull);
    });

    test('a non-200 answer is a check failure', () async {
      await serve((request) async {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
      });
      final client = UpdateClient(
        currentVersion: '1.3.0+10',
        releaseUrl: url,
      );
      await expectLater(
        client.fetchLatest(),
        throwsA(isA<UpdateCheckException>()),
      );
    });

    test('an oversized metadata body is refused before parsing', () async {
      await serve((request) async {
        request.response.add(List.filled(maxUpdateMetadataBytes + 1, 0x20));
        await request.response.close();
      });
      final client = UpdateClient(
        currentVersion: '1.3.0+10',
        releaseUrl: url,
      );
      await expectLater(
        client.fetchLatest(),
        throwsA(isA<UpdateCheckException>()),
      );
    });

    test('a malformed answer is not an error, just no release', () async {
      await serve((request) async {
        request.response.write('{"tag_name": 42}');
        await request.response.close();
      });
      final client = UpdateClient(
        currentVersion: '1.3.0+10',
        releaseUrl: url,
      );
      expect(await client.fetchLatest(), isNull);
    });

    test('download writes the asset and reports progress', () async {
      final bytes = List<int>.generate(8192, (i) => i % 256);
      await serve((request) async {
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      });
      final dir = await Directory.systemTemp.createTemp('soty-update-test');
      addTearDown(() => dir.delete(recursive: true));
      final target = File('${dir.path}/update.apk');
      final progress = <double?>[];
      final client = UpdateClient(currentVersion: '1.3.0+10');
      final written = await client.download(
        UpdateRelease(
          version: '1.4.0+11',
          parsed: const AppVersion(1, 4, 0, 11),
          apkUrl: url.toString(),
          apkSize: bytes.length,
          notes: '',
        ),
        target,
        onProgress: progress.add,
      );

      expect(written, bytes.length);
      expect(await target.readAsBytes(), bytes);
      expect(progress, isNotEmpty);
      expect(progress.last, 1.0);
    });

    test('download accepts an asset whose sha256 matches the notes', () async {
      final bytes = List<int>.generate(4096, (i) => i % 256);
      await serve((request) async {
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      });
      final sum = bytesToHex(Sha256().toSync().hashSync(bytes).bytes);
      final dir = await Directory.systemTemp.createTemp('soty-update-test');
      addTearDown(() => dir.delete(recursive: true));
      final target = File('${dir.path}/update.apk');
      final client = UpdateClient(currentVersion: '1.3.0+10');
      final written = await client.download(
        UpdateRelease(
          version: '1.4.0+11',
          parsed: const AppVersion(1, 4, 0, 11),
          apkUrl: url.toString(),
          apkSize: bytes.length,
          notes: '',
          apkSha256: sum,
        ),
        target,
      );
      expect(written, bytes.length);
      expect(await target.exists(), isTrue);
    });

    test('a single flipped byte is refused and the file deleted', () async {
      final bytes = List<int>.generate(4096, (i) => i % 256);
      final sum = bytesToHex(Sha256().toSync().hashSync(bytes).bytes);
      bytes[2048] = (bytes[2048] + 1) % 256;
      await serve((request) async {
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      });
      final dir = await Directory.systemTemp.createTemp('soty-update-test');
      addTearDown(() => dir.delete(recursive: true));
      final target = File('${dir.path}/update.apk');
      final client = UpdateClient(currentVersion: '1.3.0+10');
      await expectLater(
        client.download(
          UpdateRelease(
            version: '1.4.0+11',
            parsed: const AppVersion(1, 4, 0, 11),
            apkUrl: url.toString(),
            apkSize: bytes.length,
            notes: '',
            apkSha256: sum,
          ),
          target,
        ),
        throwsA(isA<UpdateChecksumException>()),
      );
      expect(await target.exists(), isFalse);
    });

    test('download refuses an asset past the size cap', () async {
      await serve((request) async {
        request.response.add([1, 2, 3]);
        await request.response.close();
      });
      final dir = await Directory.systemTemp.createTemp('soty-update-test');
      addTearDown(() => dir.delete(recursive: true));
      final target = File('${dir.path}/update.apk');
      final client = UpdateClient(currentVersion: '1.3.0+10');
      await expectLater(
        client.download(
          UpdateRelease(
            version: '1.4.0+11',
            parsed: const AppVersion(1, 4, 0, 11),
            apkUrl: url.toString(),
            apkSize: maxUpdateApkBytes + 1,
            notes: '',
          ),
          target,
        ),
        throwsA(isA<UpdateCheckException>()),
      );
      expect(await target.exists(), isFalse);
    });

    test('a failed download leaves no partial file behind', () async {
      await serve((request) async {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
      final dir = await Directory.systemTemp.createTemp('soty-update-test');
      addTearDown(() => dir.delete(recursive: true));
      final target = File('${dir.path}/update.apk');
      final client = UpdateClient(currentVersion: '1.3.0+10');
      await expectLater(
        client.download(
          UpdateRelease(
            version: '1.4.0+11',
            parsed: const AppVersion(1, 4, 0, 11),
            apkUrl: url.toString(),
            apkSize: 0,
            notes: '',
          ),
          target,
        ),
        throwsA(isA<UpdateCheckException>()),
      );
      expect(await target.exists(), isFalse);
    });
  });
}
