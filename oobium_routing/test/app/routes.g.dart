part of 'routes.dart';

typedef Build<T extends AppRoute> = void Function(AppRoutes<T> r);

class _Routes {
  final Build<HomeRoute> _build;
  _Routes(this._build);
  _Routes$ call() => _Routes$(_build);
  _RoutesAtAuthorsRoute atAuthorsRoute(Build<AuthorsRoute> build) =>
      _RoutesAtAuthorsRoute(build);
  _RoutesAtBooksRoute atBooksRoute(Build<BooksRoute> build) =>
      _RoutesAtBooksRoute(build);
  Object atSettingsRoute(Build build) => Object();
}

class _Routes$ {
  final AppRoutes<HomeRoute> _routes;
  late final AppRouterState _state;
  _Routes$(Build<HomeRoute> build)
      : _routes = AppRoutes<HomeRoute>({
          '/authors': (_) => AuthorsRoute(),
          '/books': (_) => BooksRoute(),
          '/settings': (_) => SettingsRoute(),
          '/authors/<>': (data) => AuthorRoute(
                id: data[0],
              ),
          '/books/<>': (data) => BookRoute(
                id: data[0],
              )
        }) {
    build(_routes);
    _state = AppRouterState('_Routes', _routes);
  }
  AppRouteParser createRouteParser() => AppRouteParser(_routes);
  AppRouterDelegate createRouterDelegate() =>
      AppRouterDelegate(_routes, _state, primary: true);
  AppRoute fromOrdinal(int ordinal) {
    switch (ordinal) {
      case 0:
        return AuthorsRoute();
      case 1:
        return BooksRoute();
      case 2:
        return SettingsRoute();
    }
    throw 'invalid ordinal: $ordinal';
  }

  void addFromOrdinal(int ordinal) => _state.add(fromOrdinal(ordinal));
  void putFromOrdinal(int ordinal) => _state.put(fromOrdinal(ordinal));
  void setFromOrdinal(int ordinal) => _state.set(fromOrdinal(ordinal));
  void setNewRoutePath(AppRoute route) => _state.setNewRoutePath(route);
  AppRoute get current => _state.last;
  void pop() => _state.pop();
  void addAuthors() => _state.add(AuthorsRoute());
  void putAuthors() => _state.put(AuthorsRoute());
  void setAuthors() => _state.set(AuthorsRoute());
  void addBooks() => _state.add(BooksRoute());
  void putBooks() => _state.put(BooksRoute());
  void setBooks() => _state.set(BooksRoute());
  void addSettings() => _state.add(SettingsRoute());
  void putSettings() => _state.put(SettingsRoute());
  void setSettings() => _state.set(SettingsRoute());
}

class AuthorsRoute extends AppRoute {
  const AuthorsRoute();
  @override
  bool operator ==(Object? other) =>
      identical(this, other) || (runtimeType == other?.runtimeType);
  @override
  int get hashCode => runtimeType.hashCode;
  @override
  int toOrdinal() => 0;
  @override
  String toString() => '/authors';
}

class BooksRoute extends AppRoute {
  const BooksRoute();
  @override
  bool operator ==(Object? other) =>
      identical(this, other) || (runtimeType == other?.runtimeType);
  @override
  int get hashCode => runtimeType.hashCode;
  @override
  int toOrdinal() => 1;
  @override
  String toString() => '/books';
}

class SettingsRoute extends AppRoute {
  const SettingsRoute();
  @override
  bool operator ==(Object? other) =>
      identical(this, other) || (runtimeType == other?.runtimeType);
  @override
  int get hashCode => runtimeType.hashCode;
  @override
  int toOrdinal() => 2;
  @override
  String toString() => '/settings';
}

class _RoutesAtAuthorsRoute {
  final Build<AuthorsRoute> _build;
  _RoutesAtAuthorsRoute(this._build);
  _RoutesAtAuthorsRoute$ call(_Routes$ parent) =>
      _RoutesAtAuthorsRoute$(parent._state, _build);
  Object atAuthorRoute(Build build) => Object();
}

class _RoutesAtAuthorsRoute$ {
  final AppRoutes<AuthorsRoute> _routes;
  late final AppRouterState _state;
  _RoutesAtAuthorsRoute$(AppRouterState parent, Build<AuthorsRoute> build)
      : _routes = AppRoutes<AuthorsRoute>() {
    build(_routes);
    _state = AppRouterState('_RoutesAtAuthorsRoute', _routes, parent: parent);
  }
  ChildRouter router() => ChildRouter(
      '_RoutesAtAuthorsRoute', () => AppRouterDelegate(_routes, _state));
  AppRoute get current => _state.last;
  void pop() => _state.pop();
  void addAuthor({required String id}) => _state.add(AuthorRoute(id: id));
  void putAuthor({required String id}) => _state.put(AuthorRoute(id: id));
  void setAuthor({required String id}) => _state.set(AuthorRoute(id: id));
}

class AuthorRoute extends AppRoute {
  final String id;
  final authors = const AuthorsRoute();
  const AuthorRoute({required this.id});
  @override
  bool operator ==(Object? other) =>
      identical(this, other) ||
      (runtimeType == other?.runtimeType &&
          other is AuthorRoute &&
          id == other.id);
  @override
  int get hashCode => hashValues(runtimeType, id);
  @override
  int toOrdinal() => 0;
  @override
  List<AppRoute> toStack() => [...authors.toStack(), this];
  @override
  String toString() => '$authors/$id';
}

class _RoutesAtBooksRoute {
  final Build<BooksRoute> _build;
  _RoutesAtBooksRoute(this._build);
  _RoutesAtBooksRoute$ call(_Routes$ parent) =>
      _RoutesAtBooksRoute$(parent._state, _build);
  Object atBookRoute(Build build) => Object();
}

class _RoutesAtBooksRoute$ {
  final AppRoutes<BooksRoute> _routes;
  late final AppRouterState _state;
  _RoutesAtBooksRoute$(AppRouterState parent, Build<BooksRoute> build)
      : _routes = AppRoutes<BooksRoute>() {
    build(_routes);
    _state = AppRouterState('_RoutesAtBooksRoute', _routes, parent: parent);
  }
  ChildRouter router() => ChildRouter(
      '_RoutesAtBooksRoute', () => AppRouterDelegate(_routes, _state));
  AppRoute get current => _state.last;
  void pop() => _state.pop();
  void addBook({required String id}) => _state.add(BookRoute(id: id));
  void putBook({required String id}) => _state.put(BookRoute(id: id));
  void setBook({required String id}) => _state.set(BookRoute(id: id));
}

class BookRoute extends AppRoute {
  final String id;
  final books = const BooksRoute();
  const BookRoute({required this.id});
  @override
  bool operator ==(Object? other) =>
      identical(this, other) ||
      (runtimeType == other?.runtimeType &&
          other is BookRoute &&
          id == other.id);
  @override
  int get hashCode => hashValues(runtimeType, id);
  @override
  int toOrdinal() => 0;
  @override
  List<AppRoute> toStack() => [...books.toStack(), this];
  @override
  String toString() => '$books/$id';
}
