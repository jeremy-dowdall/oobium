import 'package:string_x/string_x.dart';
import 'package:test/test.dart';

void main() {
  group('test camelCase', () {
    test('null', () => expect(null.camelCase, isEmpty));
    test('mymodel', () => expect('mymodel'.camelCase, 'Mymodel'));
    test('my_model', () => expect('my_model'.camelCase, 'MyModel'));
    test('MY_MODEL', () => expect('MY_MODEL'.camelCase, 'MyModel'));
    test('MODEL', () => expect('MODEL'.camelCase, 'Model'));
    test('myModel', () => expect('myModel'.camelCase, 'MyModel'));
    test('my model', () => expect('my model'.camelCase, 'MyModel'));
    test('MY MODEL', () => expect('MY MODEL'.camelCase, 'MyModel'));
    test('my  model', () => expect('my  model'.camelCase, 'MyModel'));
    test('MY  MODEL', () => expect('MY  MODEL'.camelCase, 'MyModel'));
    test('my_ Model', () => expect('my_ Model'.camelCase, 'MyModel'));
    test('MY _ MODEL', () => expect('MY _ MODEL'.camelCase, 'MyModel'));
    test('AModel', () => expect('AModel'.camelCase, 'AModel'));
    test('ABCModel', () => expect('ABCModel'.camelCase, 'AbcModel'));
  });

  group('test titleize', () {
    test('null', () => expect(null.titleized, isEmpty));
    test('mymodel', () => expect('mymodel'.titleized, 'Mymodel'));
    test('my_model', () => expect('my_model'.titleized, 'My Model'));
    test('MY_MODEL', () => expect('MY_MODEL'.titleized, 'My Model'));
    test('MODEL', () => expect('MODEL'.titleized, 'Model'));
    test('MyModel', () => expect('MyModel'.titleized, 'My Model'));
    test('myModel', () => expect('myModel'.titleized, 'My Model'));
    test('my model', () => expect('my model'.titleized, 'My Model'));
    test('MY MODEL', () => expect('MY MODEL'.titleized, 'My Model'));
    test('my  model', () => expect('my  model'.titleized, 'My Model'));
    test('MY  MODEL', () => expect('MY  MODEL'.titleized, 'My Model'));
    test('my_ Model', () => expect('my_ Model'.titleized, 'My Model'));
    test('MY _ MODEL', () => expect('MY _ MODEL'.titleized, 'My Model'));
  });

  group('test underscored', () {
    test('null', () => expect(null.underscored, isEmpty));
    test('model', () => expect('model'.underscored, 'model'));
    test('Model', () => expect('Model'.underscored, 'model'));
    test('MyModel', () => expect('MyModel'.underscored, 'my_model'));
    test('My Model', () => expect('My Model'.underscored, 'my_model'));
    test('A Model', () => expect('A Model'.underscored, 'a_model'));
    test('AModel', () => expect('AModel'.underscored, 'a_model'));
    test('ABCModel', () => expect('ABCModel'.underscored, 'abc_model'));
    test('com.test.Ab', () => expect('com.test.Ab'.underscored, 'com.test.ab'));
    test('ABC Files', () => expect('ABC Files'.underscored, 'abc_files'));
    test('my  model', () => expect('my  model'.underscored, 'my_model'));
    test('MY  MODEL', () => expect('MY  MODEL'.underscored, 'my_model'));
    test('my_ Model', () => expect('my_ Model'.underscored, 'my_model'));
    test('MY _ MODEL', () => expect('MY _ MODEL'.underscored, 'my_model'));
  });

  group('test varName', () {
    test('null', () => expect(null.varName, isEmpty));
    test('mymodel', () => expect('mymodel'.varName, 'mymodel'));
    test('my_model', () => expect('my_model'.varName, 'myModel'));
    test('MY_MODEL', () => expect('MY_MODEL'.varName, 'myModel'));
    test('MODEL', () => expect('MODEL'.varName, 'model'));
    test('MYmodel', () => expect('MYmodel'.varName, 'mYmodel'));
    test('myModel', () => expect('myModel'.varName, 'myModel'));
    test('my model', () => expect('my model'.varName, 'myModel'));
    test('MY MODEL', () => expect('MY MODEL'.varName, 'myModel'));
    test('my  model', () => expect('my  model'.varName, 'myModel'));
    test('MY  MODEL', () => expect('MY  MODEL'.varName, 'myModel'));
    test('my_ Model', () => expect('my_ Model'.varName, 'myModel'));
    test('MY _ MODEL', () => expect('MY _ MODEL'.varName, 'myModel'));
  });
}