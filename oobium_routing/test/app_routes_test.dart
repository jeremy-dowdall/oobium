import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oobium_routing/src/routing.dart';

import 'utils.dart';

void main() {
  group('route', () {
    test('equals', () {
      expect(TestRoute1() == TestRoute1(), isTrue);
      expect(TestRoute1() == TestRoute2(), isFalse);
      expect(TestRoute1({'id': '1'}) == TestRoute1({'id': '1'}), isTrue);
      expect(TestRoute1({'id': '1'}) == TestRoute1({'id': '2'}), isFalse);
    });
  });
  group('errors during add', () {
    test('missing type', () {
      expectError(() => AppRoutes().add(path: null, onParse: null, onBuild: null), 'missing type (add<T> where T is a type extending AppRoute)');
    });
    test('missing path', () {
      expectError(() => AppRoutes().add<TestRoute1>(path: null, onParse: null, onBuild: null), 'missing path (cannot be null or empty)');
    });
    test('missing onParse', () {
      expectError(() => AppRoutes().add<TestRoute1>(path: '/path', onParse: null, onBuild: null), 'missing onParse');
    });
    test('missing onBuild', () {
      expectError(() => AppRoutes().add<TestRoute1>(path: '/path', onParse: (_) => TestRoute1(), onBuild: null), 'missing onBuild');
    });
    test('duplicate routes', () {
      expectError(() {
        AppRoutes()
          ..add<TestRoute1>(path: '/', onParse: (_) => TestRoute1(), onBuild: (_) => [])
          ..add<TestRoute1>(path: '/path2', onParse: (_) => TestRoute1(), onBuild: (_) => [])
        ;
      }, 'duplicate route: TestRoute1');
    });
    test('duplicate paths; absolute', () {
      expectError(() {
        AppRoutes()
          ..add<TestRoute1>(path: '/', onParse: (_) => TestRoute1(), onBuild: (_) => [])
          ..add<TestRoute2>(path: '/', onParse: (_) => TestRoute2(), onBuild: (_) => [])
        ;
      }, 'duplicate path: /');
    });
    test('duplicate paths; masked', () {
      expectError(() {
        AppRoutes()
          ..add<TestRoute1>(path: '/paths/<testId>', onParse: (_) => TestRoute1(), onBuild: (_) => [])
          ..add<TestRoute2>(path: '/paths/<exampleId>', onParse: (_) => TestRoute2(), onBuild: (_) => [])
        ;
      }, 'duplicate path: /paths/<exampleId> shadows /paths/<testId>');
    });
    test('duplicate paths; mixed', () {
      expectError(() {
        AppRoutes()
          ..add<TestRoute1>(path: '/paths/1', onParse: (_) => TestRoute1(), onBuild: (_) => [])
          ..add<TestRoute2>(path: '/paths/<id>', onParse: (_) => TestRoute2(), onBuild: (_) => [])
        ;
      }, 'duplicate path: /paths/<id> shadows /paths/1');
    });
    test('expect no error; root as second', () {
      AppRoutes()
        ..add<TestRoute2>(path: '/first', onParse: (_) => TestRoute2(), onBuild: (_) => [])
        ..add<TestRoute1>(path: '/', onParse: (_) => TestRoute1(), onBuild: (_) => [])
      ;
    });
    test('expect no error; root mixed', () {
      AppRoutes()
        ..add<TestRoute1>(path: '/', onParse: (_) => TestRoute1(), onBuild: (_) => [])
        ..add<TestRoute2>(path: '/<id>', onParse: (_) => TestRoute2(), onBuild: (_) => [])
      ;
    });
    test('expect no error; nested', () {
      AppRoutes()
        ..add<TestRoute1>(
          path: '/books', onParse: (_) => TestRoute1(), onBuild: (_) => [],
          children: AppRoutes()
            ..add<TestRoute2>(path: '/', onParse: (_) => TestRoute2(), onBuild: (_) => [])
            ..add<TestRoute3>(path: '/<id>', onParse: (_) => TestRoute3(), onBuild: (_) => [])
        )
        ..add<TestRoute4>(path: '/settings', onParse: (_) => TestRoute4(), onBuild: (_) => [])
      ;
    });
  });
  group('test guards', () {
    test('guard, 1 level', () {
      final routes = AppRoutes()
        ..add<TestRoute1>(path: '/first', onParse: (_) => TestRoute1(), onBuild: (_) => [page('first')],
          onGuard: (_) => TestRoute2()
        )
        ..add<TestRoute2>(path: '/second', onParse: (_) => TestRoute2(), onBuild: (_) => [page('second')])
      ;
      routes.state.route = TestRoute1();
      final pages = routes.getPages();
      expect(pages.length, 2);
      expect(pages[0].name, 'first');
      expect(pages[1].name, 'second');
    });
    test('guard, 2 levels', () {
      final routes = AppRoutes()
        ..add<TestRoute1>(path: '/first', onParse: (_) => TestRoute1(), onBuild: (_) => [page('first')],
          onGuard: (_) => TestRoute2()
        )
        ..add<TestRoute2>(path: '/second', onParse: (_) => TestRoute2(), onBuild: (_) => [page('second')],
          onGuard: (_) => TestRoute3()
        )
        ..add<TestRoute3>(path: '/third', onParse: (_) => TestRoute3(), onBuild: (_) => [page('third')])
      ;
      routes.state.route = TestRoute1();
      final pages = routes.getPages();
      expect(pages.length, 3);
      expect(pages[0].name, 'first');
      expect(pages[1].name, 'second');
      expect(pages[2].name, 'third');
    });
  });
}

class TestRoute1 extends AppRoute { TestRoute1([Map<String, String> data]) : super(data); }
class TestRoute2 extends AppRoute { TestRoute2([Map<String, String> data]) : super(data); }
class TestRoute3 extends AppRoute { }
class TestRoute4 extends AppRoute { }

Page page(String name) => MaterialPage(name: name, child: Container());