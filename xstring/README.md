# xstring
[![pub package](https://img.shields.io/pub/v/xstring.svg)](https://pub.dev/packages/xstring)

String extensions to make working with String? variables more convenient.
Useful for dealing with empty and nullable strings (isBlank, orElse, etc),
code generation (camelCase, underscored, etc) or general output of data (titleize, initials, etc).

# Usage
To use this plugin, add `xstring` as a [dependency in your pubspec.yaml file](https://flutter.dev/platform-plugins/).

# Example
```dart
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


  // dealing with potentialy null and/or empty strings
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


  // string parsing and collection-like conveniences
  // (see also the 'characters' dart package)
  final data = 'some-special-code';
  print(data.substr(5, -5));
  // output: special

  print(data.skip(5).take(7));
  // output: special

  print(data.last(12));
  // output: special-code
}
```
