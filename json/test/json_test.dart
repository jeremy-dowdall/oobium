import 'package:json/convert.dart';
import 'package:test/test.dart';

void main() {
  group('test decodeDateTime', () {
    test('null', () => expect(null, decodeDateTime(null)));
    test('string', () => expect('2021-06-13 07:22:00.000', decodeDateTime('2021-06-13 07:22').toString()));
    test('string, at', () => expect('0001-01-01 07:22:00.000', decodeDateTime('2021-06-13 07:22', field: 'testAt').toString()));
    test('string, on', () => expect('2021-06-13 00:00:00.000', decodeDateTime('2021-06-13 07:22', field: 'testOn').toString()));
  });
}