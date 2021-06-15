import 'package:xstring/xstring.dart';

void main() {

  // displaying string data
  final name = 'foo bar';

  print('${name.titleized} (${name.initials})');
  // output: Foo Bar (FB)

  print(name.camelCase);
  // output: fooBar

  print(name.underscored);
  // output: foo_bar


  // dealing with potentially null and/or empty strings
  String? test = null;
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

  print(test.prefix('result: ').orElse('no data'));
  // output: result: string 1

  test = null;
  print(test.orElse('string 2'));
  // output: string 2

  print(test.prefix('result: ').orElse('no data'));
  // output: no data


  // string parsing and collection-like conveniences
  // (see also the 'characters' dart package)
  final data = 'my-special-code';
  print(data.slice(3, -5));
  // output: special

  print(data.skip(3).take(7));
  // output: special

  print(data.skip(-5).take(-7));
  // output: special
}
