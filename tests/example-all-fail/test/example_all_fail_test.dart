import 'package:leap/example_all_fail.dart';
import 'package:test/test.dart';

final leap = Leap();

void main() {
  group('Leap', () {
    test('year not divisible by 4 in common year', () {
      final bool result = leap.leapYear(2015);
      expect(result, equals(false));
    }, skip: false);

    test('year divisible by 4, not divisible by 100 in leap year', () {
      final bool result = leap.leapYear(1996);
      expect(result, equals(true));
    }, skip: true);
  });
}
