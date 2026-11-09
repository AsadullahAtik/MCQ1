import 'package:flutter_test/flutter_test.dart';
import 'package:livemcq_app/bn.dart';
import 'package:livemcq_app/messages.dart';

void main() {
  test('bn converts digits only', () {
    expect(bn(2026), '২০২৬');
    expect(bn('A1'), 'A১');
  });
  test('clock formats minutes:seconds and hours', () {
    expect(clock(125), '০২:০৫');
    expect(clock(3725), '১:০২:০৫');
    expect(clock(-3), '০০:০০');
  });
  test('marks drops a useless .0 and rounds to 2 places', () {
    expect(marks(3.0), '৩');
    expect(marks(72.5), '৭২.৫');
    expect(marks(3.014), '৩.০১');
  });
  test('errorMessage knows the server codes and falls back', () {
    expect(errorMessage(ApiException(401, 'INVALID_CREDENTIALS')), contains('ঠিক নয়'));
    expect(errorMessage(ApiException(500, 'WHATEVER')), contains('WHATEVER'));
    expect(errorMessage(Exception('x')), contains('যোগাযোগ'));
  });
}
