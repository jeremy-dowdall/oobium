class InvalidTypeException implements Exception {

  final Type? actual;
  final Type expected;
  final String? _message;

  InvalidTypeException({
    required this.actual,
    required this.expected,
    String? message
  }) : _message = message;

  InvalidTypeException.value(value, {required Type type, String? message}) :
      actual = value?.runtimeType, expected = type, _message = message;

  String get message => _message ?? 'expected $expected, but was $actual';

  @override
  String toString() => '$runtimeType: $message';
}