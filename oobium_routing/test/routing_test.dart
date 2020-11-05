import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oobium_routing/src/routing.dart';

void main() {
  group('parseRouteInformation', () {
    test('masked path runtimeType', () async {
      final routes = AppRoutes()..add<TestRoute>(path: '/paths/<id>', onParse: (_) => TestRoute(), onBuild: (_) => []);
      final routeInformation = RouteInformation(location: '/paths/1');
      final route = await routes.parseRouteInformation(routeInformation);
      expect(route.runtimeType, TestRoute);
    });
    test('masked path data', () async {
      final routes = AppRoutes()..add<TestRoute>(path: '/paths/<id>', onParse: (data) => TestRoute(data), onBuild: (_) => []);
      final routeInformation = RouteInformation(location: '/paths/1');
      final route = await routes.parseRouteInformation(routeInformation);
      expect(route['id'], '1');
    });
  });
}

class TestRoute extends AppRoute { TestRoute([Map<String, String> data]) : super(data); }
