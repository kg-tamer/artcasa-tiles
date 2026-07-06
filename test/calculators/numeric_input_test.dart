import 'package:flutter_test/flutter_test.dart';
import 'package:tilemate/calculators/common/numeric_input.dart';

void main() {
  group('parsePositiveDouble', () {
    test('accepts a valid positive value', () {
      expect(parsePositiveDouble('12.5'), 12.5);
    });

    test('accepts values with surrounding whitespace', () {
      expect(parsePositiveDouble('  8  '), 8.0);
    });

    test('rejects zero', () {
      expect(parsePositiveDouble('0'), isNull);
    });

    test('rejects negative values', () {
      expect(parsePositiveDouble('-5'), isNull);
    });

    test('rejects empty, null, and non-numeric text', () {
      expect(parsePositiveDouble(''), isNull);
      expect(parsePositiveDouble(null), isNull);
      expect(parsePositiveDouble('abc'), isNull);
    });

    test('accepts a large but realistic value', () {
      expect(parsePositiveDouble('999999999'), 999999999.0);
    });

    test('rejects a digit string long enough to overflow to Infinity', () {
      // Still just digits (would pass the numeric input formatter
      // keystroke-by-keystroke), but numerically exceeds a double's ~1.8e308
      // max, so double.parse would return double.infinity if not guarded.
      final hugeNumeral = '9' * 400;
      expect(double.parse(hugeNumeral).isFinite, isFalse); // sanity check
      expect(parsePositiveDouble(hugeNumeral), isNull);
    });
  });

  group('parseNonNegativeDouble', () {
    test('accepts zero', () {
      expect(parseNonNegativeDouble('0'), 0.0);
    });

    test('accepts positive values', () {
      expect(parseNonNegativeDouble('10'), 10.0);
    });

    test('rejects negative values', () {
      expect(parseNonNegativeDouble('-1'), isNull);
    });

    test('rejects empty, null, and non-numeric text', () {
      expect(parseNonNegativeDouble(''), isNull);
      expect(parseNonNegativeDouble(null), isNull);
      expect(parseNonNegativeDouble('abc'), isNull);
    });

    test('rejects a digit string long enough to overflow to Infinity', () {
      expect(parseNonNegativeDouble('9' * 400), isNull);
    });
  });

  group('parsePositiveInt', () {
    test('accepts a valid positive integer', () {
      expect(parsePositiveInt('40'), 40);
    });

    test('rejects zero', () {
      expect(parsePositiveInt('0'), isNull);
    });

    test('rejects negative values', () {
      expect(parsePositiveInt('-3'), isNull);
    });

    test('rejects decimals (counts must be whole numbers)', () {
      expect(parsePositiveInt('4.5'), isNull);
    });

    test('rejects empty, null, and non-numeric text', () {
      expect(parsePositiveInt(''), isNull);
      expect(parsePositiveInt(null), isNull);
      expect(parsePositiveInt('abc'), isNull);
    });
  });

  group('parseNonNegativeInt', () {
    test('accepts zero', () {
      expect(parseNonNegativeInt('0'), 0);
    });

    test('accepts a valid positive integer', () {
      expect(parseNonNegativeInt('40'), 40);
    });

    test('rejects negative values', () {
      expect(parseNonNegativeInt('-3'), isNull);
    });

    test('rejects decimals (counts must be whole numbers)', () {
      expect(parseNonNegativeInt('4.5'), isNull);
    });

    test('rejects empty, null, and non-numeric text', () {
      expect(parseNonNegativeInt(''), isNull);
      expect(parseNonNegativeInt(null), isNull);
      expect(parseNonNegativeInt('abc'), isNull);
    });
  });
}
