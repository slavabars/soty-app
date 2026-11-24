import 'package:dtm_app/core/crypto/safety_number.dart';
import 'package:flutter_test/flutter_test.dart';

final _myX = '11' * 32;
final _myEd = '22' * 32;
final _theirX = '33' * 32;
final _theirEd = '44' * 32;

Future<String> _code({
  String? myX,
  String? myEd,
  String? theirX,
  String? theirEd,
}) {
  return SafetyNumber.forPair(
    myX: myX ?? _myX,
    myEd: myEd ?? _myEd,
    theirX: theirX ?? _theirX,
    theirEd: theirEd ?? _theirEd,
  );
}

void main() {
  test('a safety number is 12 groups of five digits', () async {
    final code = await _code();
    final groups = code.split(' ');
    expect(groups, hasLength(12));
    for (final group in groups) {
      expect(group, matches(RegExp(r'^\d{5}$')));
    }
  });

  test('both sides compute the same safety number', () async {
    final mine = await _code();
    final theirs = await SafetyNumber.forPair(
      myX: _theirX,
      myEd: _theirEd,
      theirX: _myX,
      theirEd: _myEd,
    );
    expect(theirs, mine);
  });

  test('the same keys always produce the same safety number', () async {
    expect(await _code(), await _code());
  });

  test('the format is pinned so a code change cannot go unnoticed', () async {
    expect(
      await _code(),
      '37620 04351 81079 72822 58595 73939 '
      '69548 46256 31940 25208 10354 73423',
    );
  });

  test('any changed key produces a different safety number', () async {
    final base = await _code();
    expect(await _code(myX: '55' * 32), isNot(base));
    expect(await _code(myEd: '55' * 32), isNot(base));
    expect(await _code(theirX: '55' * 32), isNot(base));
    expect(await _code(theirEd: '55' * 32), isNot(base));
  });

  test('uppercase hex is accepted and equivalent to lowercase', () async {
    final lower = await _code();
    final upper = await SafetyNumber.forPair(
      myX: _myX.toUpperCase(),
      myEd: _myEd.toUpperCase(),
      theirX: _theirX.toUpperCase(),
      theirEd: _theirEd.toUpperCase(),
    );
    expect(upper, lower);
  });

  test('malformed keys are rejected, never hashed', () async {
    await expectLater(_code(myX: 'zz'), throwsFormatException);
    await expectLater(_code(myEd: '11' * 31), throwsFormatException);
    await expectLater(_code(theirX: ''), throwsFormatException);
    await expectLater(
      _code(theirEd: '${'11' * 32}00'),
      throwsFormatException,
    );
  });

  test('comparison ignores spacing but not different digits', () async {
    final code = await _code();
    final compact = code.replaceAll(' ', '');
    expect(SafetyNumber.matches(code, compact), isTrue);
    final digits = SafetyNumber.digitsOnly(code);
    final flipped = (digits[0] == '9' ? '0' : '9') + digits.substring(1);
    expect(SafetyNumber.matches(code, flipped), isFalse);
    expect(SafetyNumber.matches(code, 'not a code'), isFalse);
    expect(SafetyNumber.matches(code, ''), isFalse);
  });

  test('scanned payloads may arrive as a URL or free text', () async {
    final code = await _code();
    final compact = code.replaceAll(' ', '');
    expect(
      SafetyNumber.matches(code, 'soty:safety:$compact'),
      isTrue,
    );
    expect(
      SafetyNumber.matches(code, 'Safety code: $code.'),
      isTrue,
    );
  });
}
