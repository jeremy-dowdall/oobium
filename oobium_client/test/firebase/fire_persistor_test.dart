import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:oobium_client/src/firebase/fire_persistor.dart';
import 'package:oobium_client/src/models.dart';

void main() {
  group('test collectionName(T)', () {
    test('where T is simple', () {
      expect(FirePersistor.collectionName(''.runtimeType), 'strings');
    });
    test('where T has a subtype: List<String>', () {
      expect(FirePersistor.collectionName(List<String>().runtimeType), 'lists');
    });
    test('where T has an implied subtype: List<dynamic>', () {
      expect(FirePersistor.collectionName(List().runtimeType), 'lists');
    });
  });
}

class TestClass<T> extends Mock implements Model<TestClass, TestClass> { }