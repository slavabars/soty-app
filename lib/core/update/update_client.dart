import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart' show Sha256;

import '../crypto/hex.dart' show bytesToHex, isHexOfLength;
import '../security_limits.dart';
import 'version_compare.dart';

/// An asset URL is only usable when it is https on GitHub: the metadata is
/// authenticated, but the app still refuses to hand an arbitrary URL (or a
/// plaintext one) to the downloader.
Uri? _trustedAssetUrl(String url) {
  if (url.length > maxUpdateAssetUrlLength) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.scheme != 'https') return null;
  const trustedHosts = {'github.com', 'objects.githubusercontent.com'};
  if (!trustedHosts.contains(uri.host)) return null;
  return uri;
}

/// One installable release as advertised by the feed.
final class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.parsed,
    required this.apkUrl,
    required this.apkSize,
    required this.notes,
    this.apkSha256,
  });

  /// The advertised version without a leading `v`, e.g. `1.4.0+11`.
  final String version;
  final AppVersion parsed;

  /// Absolute `https://github.com/...` URL of the APK asset.
  final String apkUrl;

  /// Advertised asset size in bytes; `0` when the feed omits it.
  final int apkSize;

  /// Release notes excerpt (already bounded).
  final String notes;

  /// SHA-256 of the APK as published in the release notes' file table, or
  /// `null` when the operator published no digest. When present, a downloaded
  /// asset must match it byte for byte or it is never handed to the installer.
  final String? apkSha256;

  /// The subset stored between launches, so a update found once stays visible
  /// in Settings even while the daily check is not due.
  String toJson() => jsonEncode({
    'version': version,
    'apkUrl': apkUrl,
    'apkSize': apkSize,
    'notes': notes,
    'apkSha256': apkSha256,
  });

  /// Restores [toJson]'s output, re-validating everything: the stored blob is
  /// on-device state and could be corrupt, so a bad value yields `null`
  /// instead of an exception.
  static UpdateRelease? fromJson(String raw) {
    if (raw.isEmpty || raw.length > maxUpdateMetadataBytes) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final version = decoded['version'];
    final apkUrl = decoded['apkUrl'];
    final apkSize = decoded['apkSize'];
    final notes = decoded['notes'];
    final apkSha256 = decoded['apkSha256'];
    if (version is! String || apkUrl is! String) return null;
    if (notes is! String || notes.length > maxUpdateNotesChars) return null;
    if (apkSha256 != null &&
        (apkSha256 is! String || !isHexOfLength(apkSha256, 32))) {
      return null;
    }
    final parsed = AppVersion.tryParse(version);
    if (parsed == null) return null;
    if (_trustedAssetUrl(apkUrl) == null) return null;
    final size = apkSize is int && apkSize > 0 && apkSize <= maxUpdateApkBytes
        ? apkSize
        : 0;
    return UpdateRelease(
      version: version,
      parsed: parsed,
      apkUrl: apkUrl,
      apkSize: size,
      notes: notes,
      apkSha256: apkSha256 as String?,
    );
  }
}

/// A release check that did not produce an answer: the network failed, the
/// server refused or the reply timed out.
class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => 'UpdateCheckException: $message';
}

/// The downloaded APK is not the file the release notes advertise: bytes were
/// altered or truncated in transit. It is deleted and never installed.
class UpdateChecksumException extends UpdateCheckException {
  const UpdateChecksumException() : super('checksum mismatch');
}

/// The two operations the update controller needs from a release feed.
abstract interface class ReleaseFeed {
  /// The latest advertised release, or `null` when the feed has nothing
  /// installable. Throws [UpdateCheckException] when the request failed.
  Future<UpdateRelease?> fetchLatest();

  /// Release notes for one specific tag (the running version), or `null`.
  Future<String?> fetchTagNotes(String version);

  /// Downloads [release] to [target], reporting a 0..1 fraction.
  Future<int> download(
    UpdateRelease release,
    File target, {
    void Function(double? progress)? onProgress,
  });
}

/// Reads the "latest release" document of the project's GitHub repository and
/// streams the APK asset. No dependency beyond `dart:io`.
///
/// The document is remote, attacker-visible input on an untrusted network, so
/// the metadata read is bounded before parsing, the version tag is parsed
/// strictly, and only an `https://github.com/...apk` asset is ever accepted.
class UpdateClient implements ReleaseFeed {
  UpdateClient({
    required this.currentVersion,
    Uri? releaseUrl,
    HttpClient Function()? clientFactory,
  }) : releaseUrl = releaseUrl ?? defaultReleaseUrl,
       _clientFactory = clientFactory ?? HttpClient.new;

  static final Uri defaultReleaseUrl = Uri.https(
    'api.github.com',
    '/repos/slavabars/soty/releases/latest',
  );

  /// The running app's version, sent as the user agent and used to prefer a
  /// build-specific asset name when the release ships several.
  final String currentVersion;
  final Uri releaseUrl;
  final HttpClient Function() _clientFactory;

  /// Fetches the latest release metadata.
  ///
  /// Returns `null` when the feed carries no usable APK (a malformed tag, no
  /// `.apk` asset, a non-GitHub or non-https download URL). Throws
  /// [UpdateCheckException] when the request itself failed.
  @override
  Future<UpdateRelease?> fetchLatest() async {
    final client = _clientFactory()
      ..connectionTimeout = updateRequestTimeout;
    try {
      final request = await client.getUrl(releaseUrl).timeout(
        updateRequestTimeout,
      );
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'Soty/$currentVersion');
      final response = await request.close().timeout(updateRequestTimeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw UpdateCheckException('HTTP ${response.statusCode}');
      }
      final raw = await _readBounded(response, maxUpdateMetadataBytes);
      return parseRelease(raw);
    } on UpdateCheckException {
      rethrow;
    } on TimeoutException {
      throw const UpdateCheckException('timeout');
    } on IOException catch (error) {
      throw UpdateCheckException('${error.runtimeType}');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<String?> fetchTagNotes(String version) async {
    final cleaned = version.trim().replaceFirst(RegExp('^[vV]'), '');
    if (cleaned.isEmpty || cleaned.length > 64) return null;
    // Tests point releaseUrl at a loopback server; follow it there, otherwise
    // use the public tag endpoint.
    final uri = releaseUrl.host == 'api.github.com'
        ? Uri.https(
            'api.github.com',
            '/repos/slavabars/soty/releases/tags/v$cleaned',
          )
        : releaseUrl.replace(path: '/tags/v$cleaned');
    final client = _clientFactory()
      ..connectionTimeout = updateRequestTimeout;
    try {
      final request = await client.getUrl(uri).timeout(updateRequestTimeout);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'Soty/$currentVersion');
      final response = await request.close().timeout(updateRequestTimeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }
      final raw = await _readBounded(response, maxUpdateMetadataBytes);
      return parseNotes(raw);
    } on TimeoutException {
      return null;
    } on IOException {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// The `body` field of a release document, bounded; `null` when absent.
  static String? parseNotes(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final body = decoded['body'];
    if (body is! String) return null;
    return body.length > maxUpdateNotesChars
        ? body.substring(0, maxUpdateNotesChars)
        : body;
  }

  /// Parses a release document; `null` when nothing installable is described.
  ///
  /// Kept separate from the transport so the hostile shapes are unit-testable
  /// without a socket.
  static UpdateRelease? parseRelease(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final tag = decoded['tag_name'];
    if (tag is! String) return null;
    final parsed = AppVersion.tryParse(tag);
    if (parsed == null) return null;
    final assets = decoded['assets'];
    if (assets is! List) return null;

    Uri? bestUrl;
    var bestSize = 0;
    var bestRank = -1;
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = asset['name'];
      final url = asset['browser_download_url'];
      if (name is! String || url is! String) continue;
      if (!name.toLowerCase().endsWith('.apk')) continue;
      final uri = _trustedAssetUrl(url);
      if (uri == null) continue;
      final size = asset['size'];
      final rank = name == preferredAssetName ? 2 : 1;
      if (rank > bestRank) {
        bestRank = rank;
        bestUrl = uri;
        bestSize = size is int && size > 0 && size <= maxUpdateApkBytes
            ? size
            : 0;
      }
    }
    if (bestUrl == null) return null;

    final body = decoded['body'];
    final fullNotes = body is String ? body : '';
    final notes = fullNotes.length > maxUpdateNotesChars
        ? fullNotes.substring(0, maxUpdateNotesChars)
        : fullNotes;
    final version = tag.trim().replaceFirst(RegExp('^[vV]'), '');
    return UpdateRelease(
      version: version,
      parsed: parsed,
      apkUrl: bestUrl.toString(),
      apkSize: bestSize,
      notes: notes,
      apkSha256: parseApkDigest(fullNotes),
    );
  }

  /// The SHA-256 of [preferredAssetName] published in the release notes' file
  /// table, or `null` when the notes carry no well-formed digest.
  ///
  /// The pipeline writes one row per artifact:
  /// `| `soty-release.apk` | Android | `<64 hex>` |`. The digest is read from
  /// the *last* cell of that row, so a note that merely mentions a hash in
  /// prose is never mistaken for the asset's. The whole body is scanned, not
  /// the truncated [UpdateRelease.notes] excerpt, which may end before the
  /// table.
  static String? parseApkDigest(String notes) {
    for (final line in const LineSplitter().convert(notes)) {
      // A table row is `| name | what | sha |`; drop the empty cells the
      // leading and trailing pipes produce before reading name and digest.
      final cells = [
        for (final cell in line.split('|'))
          if (cell.trim().isNotEmpty) cell,
      ];
      if (cells.length < 2) continue;
      final name = cells.first.replaceAll('`', '').trim();
      if (name != preferredAssetName) continue;
      final digest = cells.last.replaceAll('`', '').trim().toLowerCase();
      if (isHexOfLength(digest, 32)) return digest;
    }
    return null;
  }

  /// The asset the release pipeline uploads, preferred over any other `.apk`.
  static const String preferredAssetName = 'soty-release.apk';

  /// Downloads the APK to [target] and reports progress as a 0..1 fraction
  /// (`null` while the total size is unknown).
  ///
  /// The byte count is enforced while streaming, so a lying `content-length`
  /// cannot fill the disk. Returns the number of bytes written.
  @override
  Future<int> download(
    UpdateRelease release,
    File target, {
    void Function(double? progress)? onProgress,
  }) async {
    final client = _clientFactory()
      ..connectionTimeout = updateRequestTimeout;
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(release.apkUrl)).timeout(
        updateRequestTimeout,
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Soty/$currentVersion',
      );
      final response = await request.close().timeout(updateRequestTimeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw UpdateCheckException('HTTP ${response.statusCode}');
      }
      final total = response.contentLength > 0
          ? response.contentLength
          : release.apkSize;
      if (total > maxUpdateApkBytes) {
        await response.drain<void>();
        throw const UpdateCheckException('asset too large');
      }
      final file = await target.create(recursive: true);
      sink = file.openWrite();
      final digest = Sha256().toSync().newHashSink();
      var written = 0;
      await for (final chunk in response.timeout(updateRequestTimeout)) {
        written += chunk.length;
        if (written > maxUpdateApkBytes) {
          throw const UpdateCheckException('asset too large');
        }
        sink.add(chunk);
        digest.add(chunk);
        if (onProgress != null) {
          onProgress(total > 0 ? written / total : null);
        }
      }
      await sink.flush();
      final expected = release.apkSha256;
      if (expected != null) {
        digest.close();
        final actual = bytesToHex(digest.hashSync().bytes);
        if (actual != expected) {
          throw const UpdateChecksumException();
        }
      }
      return written;
    } on UpdateCheckException {
      await sink?.close();
      sink = null;
      await _deleteQuietly(target);
      rethrow;
    } on TimeoutException {
      await sink?.close();
      sink = null;
      await _deleteQuietly(target);
      throw const UpdateCheckException('timeout');
    } on IOException catch (error) {
      await sink?.close();
      sink = null;
      await _deleteQuietly(target);
      throw UpdateCheckException('${error.runtimeType}');
    } finally {
      await sink?.close();
      client.close(force: true);
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on IOException {
      // Best effort: an unremovable partial file is overwritten next time.
    }
  }

  /// Reads at most [limit] bytes of [response], aborting a longer body instead
  /// of buffering whatever the peer feels like sending.
  static Future<String> _readBounded(
    HttpClientResponse response,
    int limit,
  ) async {
    if (response.contentLength > limit) {
      throw const UpdateCheckException('metadata too large');
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > limit) {
        throw const UpdateCheckException('metadata too large');
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}
