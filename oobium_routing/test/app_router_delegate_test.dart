import 'package:flutter_test/flutter_test.dart';
import 'package:oobium_routing/src/routing.dart';

import 'utils.dart';

void main() {
  group('nested setNewRoutePath', () {
    test('masked parent and child', () {
      final routes = AppRoutes()..add<TestRoute1>(
          path: '/parent/<parentId>', onParse: (data) => TestRoute1(data), onBuild: (_) => [],
          children: AppRoutes()
            ..add<TestRoute2>(
              path: '/default', onParse: (_) => TestRoute2(), onBuild: (_) => [],
            )
            ..add<TestRoute3>(
              path: '/child/<childId>', onParse: (data) => TestRoute3(data), onBuild: (_) => [],
            )
      );
      final delegate1 = routes.createRouterDelegate();
      final delegate2 = routes.get<TestRoute1>().createRouterDelegate();
      final route1 = TestRoute1({'parentId': '1'});
      final route2 = TestRoute2()..parent = route1;
      final route3 = TestRoute3({'childId': '2'})..parent = route1;
      delegate1.setNewRoutePath(route1);
      expect(delegate1.currentConfiguration, route1);
      expect(delegate2.currentConfiguration, null);
      expect(delegate1.routes.state.route, route1);
      expect(delegate2.routes.state.route, route2);
      delegate1.setNewRoutePath(route3);
      expect(delegate1.currentConfiguration, route3);
      expect(delegate2.currentConfiguration, null);
      expect(delegate1.routes.state.route, route1);
      expect(delegate2.routes.state.route, route3);
      delegate1.setNewRoutePath(route1); // setNewRoutePath is absolute, so sub-navigation is reset
      expect(delegate1.currentConfiguration, route1);
      expect(delegate2.currentConfiguration, null);
      expect(delegate1.routes.state.route, route1);
      expect(delegate2.routes.state.route, route2);
    });
  });
  group('nested state updates', () {
    test('masked parent and child', () {
      final routes = AppRoutes()..add<TestRoute1>(
        path: '/parent/<parentId>', onParse: (data) => TestRoute1(data), onBuild: (_) => [],
        children: AppRoutes()
          ..add<TestRoute2>(
            path: '/default', onParse: (_) => TestRoute2(), onBuild: (_) => [],
          )
          ..add<TestRoute3>(
            path: '/child/<childId>', onParse: (data) => TestRoute3(data), onBuild: (_) => [],
          )
      );
      final delegate1 = routes.createRouterDelegate();
      final delegate2 = routes.get<TestRoute1>().createRouterDelegate();
      final route1 = TestRoute1({'parentId': '1'});
      final route2 = TestRoute2()..parent = route1;
      final route3 = TestRoute3({'childId': '2'})..parent = route1;
      delegate1.routes.state.route = route1;
      expect(delegate1.currentConfiguration, route1);
      expect(delegate2.currentConfiguration, null);
      expect(delegate1.routes.state.route, route1);
      expect(delegate2.routes.state.route, route2);
      expectError(() => delegate1.routes.state.route = route3, 'unsupported route: $route3 (this is probably not the delegate you were looking for)');
      delegate2.routes.state.route = route3;
      expect(delegate1.currentConfiguration, route3);
      expect(delegate2.currentConfiguration, null);
      expect(delegate1.routes.state.route, route1);
      expect(delegate2.routes.state.route, route3);
      delegate1.routes.state.route = route1; // updating state is NOT absolute, so sub-navigation is NOT reset
      expect(delegate1.currentConfiguration, route3);
      expect(delegate2.currentConfiguration, null);
      expect(delegate1.routes.state.route, route1);
      expect(delegate2.routes.state.route, route3);
    });
  });
}

class TestRoute1 extends AppRoute { TestRoute1([Map<String, String> data]) : super(data); }
class TestRoute2 extends AppRoute { TestRoute2([Map<String, String> data]) : super(data); }
class TestRoute3 extends AppRoute { TestRoute3([Map<String, String> data]) : super(data); }
