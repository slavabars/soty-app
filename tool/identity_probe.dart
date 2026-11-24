// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Fetches the device identity from a debug build's dev-extensions server and
/// saves it as `<dir>/identity.json` for the other e2e tools.
///
/// The app keeps the seeds in the Android Keystore (T-72), so they cannot be
/// read out of a pulled database any more. The dev server exists only in debug
/// builds and only on the device loopback:
///
///   adb -s emulator-5554 forward tcp:4701 tcp:4701
///   dart run tool/identity_probe.dart /tmp/opencode/deviceA
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('usage: dart run tool/identity_probe.dart <dir> [port]');
    return;
  }
  final dir = args[0];
  final port = args.length > 1 ? int.parse(args[1]) : 4701;
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse('http://127.0.0.1:$port/'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'action': 'identity'}));
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != 200) {
      print('identity endpoint answered ${response.statusCode}: $body');
      exitCode = 1;
      return;
    }
    final identity = jsonDecode(body);
    if (identity is! Map ||
        identity['edSeedHex'] is! String ||
        identity['xSeedHex'] is! String) {
      print('unexpected identity payload: $body');
      exitCode = 1;
      return;
    }
    Directory(dir).createSync(recursive: true);
    final file = File('$dir/identity.json');
    file.writeAsStringSync(body);
    Process.runSync('chmod', ['600', file.path]);
    print('name    ${identity['displayName'] ?? ''}');
    print('wrote   ${file.path}');
  } finally {
    client.close();
  }
}
