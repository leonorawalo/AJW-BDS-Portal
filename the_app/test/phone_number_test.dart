import 'package:the_app/core/phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhoneNumber.normalise', () {
    test('Kenyan numbers in any common shape become +254…', () {
      for (final input in ['0712 345 678', '0712-345-678', '+254 712 345 678', '254712345678', '00254712345678', '(0712) 345678']) {
        expect(PhoneNumber.normalise(input), '+254712345678', reason: input);
      }
      expect(PhoneNumber.normalise('0112 345 678'), '+254112345678');
    });

    test('foreign numbers with a + are kept', () {
      expect(PhoneNumber.normalise('+44 20 7946 0958'), '+442079460958');
    });

    test('nonsense and wrong-length Kenyan numbers are refused', () {
      for (final input in ['', '   ', 'abc', '712345678', '07123', '+2547123456789', '+12']) {
        expect(PhoneNumber.normalise(input), isNull, reason: input);
      }
    });
  });

  test('display groups Kenyan numbers', () {
    expect(PhoneNumber.display('+254712345678'), '+254 712 345 678');
    expect(PhoneNumber.display('+442079460958'), '+442079460958');
  });
}
