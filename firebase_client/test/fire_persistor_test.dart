import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'file:///Users/jeremydowdall/BlackRabbit/dev/oobium/firebase_client/lib/src/fire_persistor.dart';
import 'package:oobium_client/oobium_client.dart';

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