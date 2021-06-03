import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oobium_routing/src/routing.dart';

void main() {
  group('nested parseRouteInformation', () {
    test('masked parent and child', () async {
      final routes = AppRoutes()..add<TestRoute1>(
        path: '/parent/<parentId>', onParse: (data) => TestRoute1(data), onBuild: (_) => [],
        children: AppRoutes()..add<TestRoute2>(
          path: '/child/<childId>', onParse: (data) => TestRoute2(data), onBuild: (_) => [],
        )
      );
      final route1 = await routes.parseRouteInformation(RouteInformation(location: '/parent/0'));
      expect(route1.parent, isNull);
      expect(route1.runtimeType, TestRoute1);
      expect(route1['parentId'], '0');
      final route2 = await routes.parseRouteInformation(RouteInformation(location: '/parent/1/child/2'));
      expect(route2.parent?.runtimeType, TestRoute1);
      expect(route2.parent?['parentId'], '1');
      expect(route2.runtimeType, TestRoute2);
      expect(route2['childId'], '2');
    });
    test('masked parent, child and grandchild', () async {
      final routes = AppRoutes()..add<TestRoute1>(
        path: '/parent/<parentId>', onParse: (data) => TestRoute1(data), onBuild: (_) => [],
        children: AppRoutes()..add<TestRoute2>(
          path: '/child/<childId>', onParse: (data) => TestRoute2(data), onBuild: (_) => [],
          children: AppRoutes()..add<TestRoute3>(
            path: '/grand/<grandId>', onParse: (data) => TestRoute3(data), onBuild: (_) => []
          )
        )
      );
      final route1 = await routes.parseRouteInformation(RouteInformation(location: '/parent/0'));
      expect(route1.parent, isNull);
      expect(route1.runtimeType, TestRoute1);
      expect(route1['parentId'], '0');
      final route2 = await routes.parseRouteInformation(RouteInformation(location: '/parent/1/child/2'));
      expect(route2.parent?.runtimeType, TestRoute1);
      expect(route2.parent?['parentId'], '1');
      expect(route2.runtimeType, TestRoute2);
      expect(route2['childId'], '2');
      final route3 = await routes.parseRouteInformation(RouteInformation(location: '/parent/1/child/2/grand/3'));
      expect(route3.parent?.parent?.runtimeType, TestRoute1);
      expect(route3.parent?.parent?['parentId'], '1');
      expect(route3.parent?.runtimeType, TestRoute2);
      expect(route3.parent?['childId'], '2');
      expect(route3.runtimeType, TestRoute3);
      expect(route3['grandId'], '3');
    });
  });
  group('nested restoreRouteInformation', () {
    test('masked parent and child', () async {
      final routes = AppRoutes()..add<TestRoute1>(
        path: '/parent/<parentId>', onParse: (data) => TestRoute1(data), onBuild: (_) => [],
        children: AppRoutes()..add<TestRoute2>(
          path: '/child/<childId>', onParse: (data) => TestRoute2(data), onBuild: (_) => [],
        )
      );
      final route1 = TestRoute1(RouteData({'parentId': '1'}));
      final route2 = TestRoute2(RouteData({'childId': '2'}))..parent = route1;
      expect(routes.restoreRouteInformation(route1).location, '/parent/1');
      expect(routes.restoreRouteInformation(route2).location, '/parent/1/child/2');
    });
    test('masked parent, child and grandchild', () async {
      final routes = AppRoutes()..add<TestRoute1>(
        path: '/parent/<parentId>', onParse: (data) => TestRoute1(data), onBuild: (_) => [],
        children: AppRoutes()..add<TestRoute2>(
          path: '/child/<childId>', onParse: (data) => TestRoute2(data), onBuild: (_) => [],
            children: AppRoutes()..add<TestRoute3>(
                path: '/grand/<grandId>', onParse: (data) => TestRoute3(data), onBuild: (_) => []
            )
        )
      );
      final route1 = TestRoute1(RouteData({'parentId': '1'}));
      final route2 = TestRoute2(RouteData({'childId': '2'}))..parent = route1;
      final route3 = TestRoute3(RouteData({'grandId': '3'}))..parent = route2;
      expect(routes.restoreRouteInformation(route1).location, '/parent/1');
      expect(routes.restoreRouteInformation(route2).location, '/parent/1/child/2');
      expect(routes.restoreRouteInformation(route3).location, '/parent/1/child/2/grand/3');
    });
  });
  group('nested currentConfiguration', () {
    test('masked parent and child', () async {
      final routes = AppRoutes()..add<TestRoute1>(
        path: '/parent/<parentId>', onParse: (data) => TestRoute1(data), onBuild: (_) => [],
        children: AppRoutes()..add<TestRoute2>(
          path: '/child/<childId>', onParse: (data) => TestRoute2(data), onBuild: (_) => [],
        )
      );
      final route1 = TestRoute1(RouteData({'parentId': '1'}));
      final route2 = TestRoute2(RouteData({'childId': '2'}))..parent = route1;
      expect(routes.restoreRouteInformation(route1).location, '/parent/1');
      expect(routes.restoreRouteInformation(route2).location, '/parent/1/child/2');
    });
    test('masked parent, child and grandchild', () async {
      final routes = AppRoutes()..add<TestRoute1>(
        path: '/parent/<parentId>', onParse: (data) => TestRoute1(data), onBuild: (_) => [],
        children: AppRoutes()..add<TestRoute2>(
          path: '/child/<childId>', onParse: (data) => TestRoute2(data), onBuild: (_) => [],
            children: AppRoutes()..add<TestRoute3>(
                path: '/grand/<grandId>', onParse: (data) => TestRoute3(data), onBuild: (_) => []
            )
        )
      );
      final route1 = TestRoute1(RouteData({'parentId': '1'}));
      final route2 = TestRoute2(RouteData({'childId': '2'}))..parent = route1;
      final route3 = TestRoute3(RouteData({'grandId': '3'}))..parent = route2;
      expect(routes.restoreRouteInformation(route1).location, '/parent/1');
      expect(routes.restoreRouteInformation(route2).location, '/parent/1/child/2');
      expect(routes.restoreRouteInformation(route3).location, '/parent/1/child/2/grand/3');
    });
  });
}

class TestRoute1 extends AppRoute { TestRoute1([RouteData? data]) : super(data); }
class TestRoute2 extends AppRoute { TestRoute2([RouteData? data]) : super(data); }
class TestRoute3 extends AppRoute { TestRoute3([RouteData? data]) : super(data); }
