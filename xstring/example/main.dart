import 'package:xstring/xstring.dart';

void main() {
  final name = 'foo bar';

  print('${name.titleized} (${name.initials})');
  // output: Foo Bar (FB)

  print(name.camelCase);
  // output: fooBar

  print(name.underscored);
  // output: foo_bar

  String? test = null;
  print('isBlank: ${test.isBlank}');
  // output: isBlank: true;

  test = 'null';
  print('isBlank: ${test.isBlank}');
  // output: isBlank: true;

  test = '';
  print('isBlank: ${test.isBlank}');
  // output: isBlank: true;

  test = '   ';
  print('isBlank: ${test.isBlank}');
  // output: isBlank: true;

  test = ' - ';
  print('isBlank: ${test.isBlank}');
  // output: isBlank: false;

  test = 'string 1';
  print(test.orElse('string 2'));
  // output: string 1

  test = null;
  print(test.orElse('string 2'));
  // output: string 2
}
