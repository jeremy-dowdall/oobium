# oobium_routing
[![pub package](https://img.shields.io/pub/v/string_x.svg)](https://pub.dev/packages/string_x)

String extensions to make working with String? variables more convenient.
Useful for dealing with empty and nullable strings (isBlank, orElse, etc),
code generation (camelCase, underscored, etc) or general output of data (titleize, initials, etc).

# Usage
To use this plugin, add `string_x` as a [dependency in your pubspec.yaml file](https://flutter.dev/platform-plugins/).

# Example
```dart
import 'package:string_x/string_x.dart';

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
```
