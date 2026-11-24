/// Numeric app versions of the shape `major.minor.patch[+build]`, the form of
/// the release tags (`v1.4.0+11`) this app compares itself against.
///
/// Parsing is strict and total: anything that is not three decimal components
/// with an optional numeric build (a pre-release suffix, a stray word, an
/// oversized string) is rejected instead of being guessed at, because the
/// input comes from a remote release feed.
library;

import '../security_limits.dart' show maxVersionStringLength;

final class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, [this.build = 0]);

  final int major;
  final int minor;
  final int patch;

  /// Store/build number, `0` when the string carries none.
  final int build;

  /// Parses `1.4.0`, `1.4.0+11` or `v1.4.0+11`; `null` for anything else.
  static AppVersion? tryParse(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text.length > maxVersionStringLength) return null;
    final body = text.startsWith('v') || text.startsWith('V')
        ? text.substring(1)
        : text;
    final halves = body.split('+');
    if (halves.length > 2) return null;
    final numbers = halves.first.split('.');
    if (numbers.length != 3) return null;
    final major = _component(numbers[0]);
    final minor = _component(numbers[1]);
    final patch = _component(numbers[2]);
    final build = halves.length == 2 ? _component(halves[1]) : 0;
    if (major == null || minor == null || patch == null || build == null) {
      return null;
    }
    return AppVersion(major, minor, patch, build);
  }

  /// One all-ASCII-digit component of at most nine digits; `null` otherwise so
  /// a huge number cannot overflow or soak up parsing time.
  static int? _component(String value) {
    if (value.isEmpty || value.length > 9) return null;
    for (final unit in value.codeUnits) {
      if (unit < 0x30 || unit > 0x39) return null;
    }
    return int.parse(value);
  }

  /// True when this version is strictly newer than [other].
  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return build.compareTo(other.build);
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch &&
      other.build == build;

  @override
  int get hashCode => Object.hash(major, minor, patch, build);

  @override
  String toString() => '$major.$minor.$patch+$build';
}
