import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oobium_routing/oobium_routing.dart';

import 'main.dart';

part 'routes.g.dart';

final mainBuilder = _Routes((r) => r
  ..home(show: (_) => const AuthorsRoute())
  ..page<AuthorsRoute>('/authors', (_) => AppPage('/', const HomeScreen()))
  ..page<BooksRoute>('/books', (_) => AppPage('/', const HomeScreen()))
  ..page<SettingsRoute>('/settings', (_) => AppPage('/', const HomeScreen()),
    onGuard: (s) => s.isAnonymous ? AuthorsRoute() : null,
  )
  ..notFound(view: (_) => const Text('not found'))
  ..error(view: (s) => Text('oops: ${s.route.message}')),
  watch: () => [AuthState()]
);

final authorBuilder = mainBuilder.atAuthorsRoute((r) => r
  ..home(view: (_) => AuthorsView())
  ..view<AuthorRoute>('/<id>', (s) => AuthorView(s.route.id))
);

final bookBuilder = mainBuilder.atBooksRoute((r) => r
  ..home(view: (_) => BooksView())
  ..view<BookRoute>('/<id>', (s) => BookView(s.route.id))
);

/// Custom state
class AuthState extends ValueNotifier {
  AuthState() : super(false);
  bool get isAnonymous => value;
  bool get isLoggedIn => !value;
}
extension RouterStateX on RouteState {
  bool get isAnonymous => get<AuthState>().isAnonymous;
}

/// exposes _internals for tests
class MainRoutesTester {
  final Routes routes;
  MainRoutesTester() : routes = mainBuilder() {
    routes._state.addListener(() => _eventCount++);
  }
  int _eventCount = 0;
  int get eventCount => _eventCount;
  AppRoutes<HomeRoute> get _routes => routes._routes;
  AppRouterState get state => routes._state;
  List<String> get pages => PagesBuilder(_routes, state).getPages().map((p) => '${p.name}').toList();
}

class AuthorRoutesTester {
  final RoutesAtAuthorsRoute routes;
  AuthorRoutesTester(MainRoutesTester parent) : routes = authorBuilder(parent.routes) {
    routes._state.addListener(() => _eventCount++);
  }
  int _eventCount = 0;
  int get eventCount => _eventCount;
  AppRoutes<AuthorsRoute> get _routes => routes._routes;
  AppRouterState get state => routes._state;
  List<String> get pages => PagesBuilder(_routes, state).getPages().map((p) => '${p.name}').toList();
}

class BookRoutesTester {
  final RoutesAtBooksRoute routes;
  BookRoutesTester(MainRoutesTester parent) : routes = bookBuilder(parent.routes) {
    routes._state.addListener(() => _eventCount++);
  }
  int _eventCount = 0;
  int get eventCount => _eventCount;
  AppRoutes<BooksRoute> get _routes => routes._routes;
  AppRouterState get state => routes._state;
  List<String> get pages => PagesBuilder(_routes, state).getPages().map((p) => '${p.name}').toList();
}
