import 'package:flutter/material.dart';
import 'package:oobium_routing/oobium_routing2.dart';

part 'routes.g.dart';

final mainBuilder = _Routes((r) => r
  ..home(show: (_) => const AuthorsRoute())
  ..page<AuthorsRoute>('/authors', (_,__) => AppPage('/', HomeScreen()))
  ..page<BooksRoute>('/books', (_,__) => AppPage('/', HomeScreen()))
  ..page<SettingsRoute>('/settings', (_,__) => AppPage('/', HomeScreen()))
  ..notFound(view: (_,__) => const Text('not found'))
  ..error(view: (_,r) => Text('oops: ${r.message}'))
);

final authorBuilder = mainBuilder.atAuthorsRoute((r) => r
  ..home(view: (_,__) => AuthorsView())
  ..view<AuthorRoute>('/<id>', (_,r) => AuthorView(r.id))
);

final bookBuilder = mainBuilder.atBooksRoute((r) => r
  ..home(view: (_,__) => BooksView())
  ..view<BookRoute>('/<id>', (_,r) => BookView(r.id))
);

/// exposes _internals for tests
class MainRoutesTester {
  final _def = mainBuilder();
  AppRoutes<HomeRoute> get routes => _def._routes;
  AppRouterState get state => _def._state;
  List<String> get pages => PagesBuilder(routes, state).getPages().map((p) => '${p.name}').toList();
}

class AuthorRoutesTester {
  final _RoutesAtAuthorsRoute$ _def;
  AuthorRoutesTester(MainRoutesTester parent) : _def = authorBuilder(parent._def);
  AppRoutes<AuthorsRoute> get routes => _def._routes;
  AppRouterState get state => _def._state;
  List<String> get pages => PagesBuilder(routes, state).getPages().map((p) => '${p.name}').toList();
}

class BookRoutesTester {
  final _RoutesAtBooksRoute$ _def;
  BookRoutesTester(MainRoutesTester parent) : _def = bookBuilder(parent._def);
  AppRoutes<BooksRoute> get routes => _def._routes;
  AppRouterState get state => _def._state;
  List<String> get pages => PagesBuilder(routes, state).getPages().map((p) => '${p.name}').toList();
}

/// unused view for tests
class HomeScreen extends StatelessWidget {
  @override Widget build(BuildContext context) => throw UnimplementedError();
}
class AuthorsView extends StatelessWidget {
  @override Widget build(BuildContext context) => throw UnimplementedError();
}
class AuthorView extends StatelessWidget {
  final String id;
  AuthorView(this.id);
  @override Widget build(BuildContext context) => throw UnimplementedError();
}
class BooksView extends StatelessWidget {
  @override Widget build(BuildContext context) => throw UnimplementedError();
}
class BookView extends StatelessWidget {
  final String id;
  BookView(this.id);
  @override Widget build(BuildContext context) => throw UnimplementedError();
}
