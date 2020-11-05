import 'package:test/test.dart';

void expectError(Function f, String message) {
  try {
    f();
  } catch(e) {
    expect(e.message, message);
    return;
  }
  fail('Expected an error to be thrown');
}
