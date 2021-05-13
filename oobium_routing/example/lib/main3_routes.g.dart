part of 'main3_routes.dart';

typedef Build<T extends AppRoute> = void Function(AppRoutes<T> r);

class _Routes {
  final Build<HomeRoute> _build;
  _Routes(this._build);
  _Routes$ call() => _Routes$(_build);
  Object atAuthRoute(Build build) => Object();
  _RoutesAtAuthorsRoute atAuthorsRoute(Build<AuthorsRoute> build) =>
      _RoutesAtAuthorsRoute(build);
  Object atAuthorsDetailsRoute(Build build) => Object();
  _RoutesAtBooksRoute atBooksRoute(Build<BooksRoute> build) =>
      _RoutesAtBooksRoute(build);
  Object atBooksDetailsRoute(Build build) => Object();
  Object atSettingsRoute(Build build) => Object();
}

class _Routes$ {
  final AppRoutes<HomeRoute> _routes;
  late final AppRouterState _state;
  _Routes$(Build<HomeRoute> build)
      : _routes = AppRoutes<HomeRoute>({
          '/old_path/<>/first/<>': (data) =>
              '/new_path/${data[1]}/second/${data[0]}/<var3>',
          '/sign_in': (_) => AuthRoute(),
          '/authors': (_) => AuthorsRoute(),
          '/authors/<>': (data) => AuthorsDetailsRoute(
                id: data[0],
              ),
          '/books': (_) => BooksRoute(),
          '/books/<>': (data) => BooksDetailsRoute(
                id: data[0],
              ),
          '/settings': (_) => SettingsRoute(),
          '/authors/<>': (data) => AuthorDetailsRoute(
                id: data[0],
              ),
          '/authors/<>/books/<>': (data) => AuthorsBookDetailsRoute(
                authorId: data[0],
                bookId: data[1],
              ),
          '/books/<>': (data) => BookRoute(
                id: data[0],
              ),
          '/books/<>/<>': (data) => ChapterRoute(
              id: data[1],
              book: BookRoute(
                id: data[0],
              )),
          '/books/<>/<>/<>': (data) => VerseRoute(
              id: data[2],
              chapter: ChapterRoute(
                  id: data[1],
                  book: BookRoute(
                    id: data[0],
                  )))
        }) {
    build(_routes);
    _state = AppRouterState('_Routes', _routes);
  }
  AppRouteParser createRouteParser() => AppRouteParser(_routes);
  AppRouterDelegate createRouterDelegate() =>
      AppRouterDelegate(_routes, _state, primary: true);
  void setNewRoutePath(AppRoute route) => _state.setNewRoutePath(route);
  AppRoute get current => _state.last;
  void pop() => _state.pop();
  void addAuth() => _state.add(AuthRoute());
  void putAuth() => _state.put(AuthRoute());
  void setAuth() => _state.set(AuthRoute());
  void addAuthors() => _state.add(AuthorsRoute());
  void putAuthors() => _state.put(AuthorsRoute());
  void setAuthors() => _state.set(AuthorsRoute());
  void addAuthorsDetails({required String id}) =>
      _state.add(AuthorsDetailsRoute(id: id));
  void putAuthorsDetails({required String id}) =>
      _state.put(AuthorsDetailsRoute(id: id));
  void setAuthorsDetails({required String id}) =>
      _state.set(AuthorsDetailsRoute(id: id));
  void addBooks() => _state.add(BooksRoute());
  void putBooks() => _state.put(BooksRoute());
  void setBooks() => _state.set(BooksRoute());
  void addBooksDetails({required String id}) =>
      _state.add(BooksDetailsRoute(id: id));
  void putBooksDetails({required String id}) =>
      _state.put(BooksDetailsRoute(id: id));
  void setBooksDetails({required String id}) =>
      _state.set(BooksDetailsRoute(id: id));
  void addSettings() => _state.add(SettingsRoute());
  void putSettings() => _state.put(SettingsRoute());
  void setSettings() => _state.set(SettingsRoute());
}

class AuthRoute extends AppRoute {
  const AuthRoute();
  @override
  bool operator ==(Object? other) =>
      identical(this, other) || (runtimeType == other?.runtimeType);
  @override
  int get hashCode => runtimeType.hashCode;
  @override
  int toOrdinal() => 0;
  @override
  String toString() => '/sign_in';
}

class AuthorsRoute extends AppRoute {
  const AuthorsRoute();
  @override
  bool operator ==(Object? other) =>
      identical(this, other) || (runtimeType == other?.runtimeType);
  @override
  int get hashCode => runtimeType.hashCode;
  @override
  int toOrdinal() => 1;
  @override
  String toString() => '/authors';
}

class AuthorsDetailsRoute extends AppRoute {
  final String id;
  const AuthorsDetailsRoute({required this.id});
  @override
  bool operator ==(Object? other) =>
      identical(this, other) ||
      (runtimeType == other?.runtimeType &&
          other is AuthorsDetailsRoute &&
          id == other.id);
  @override
  int get hashCode => hashValues(runtimeType, id);
  @override
  int toOrdinal() => 2;
  @override
  String toString() => '/authors/$id';
}

class BooksRoute extends AppRoute {
  const BooksRoute();
  @override
  bool operator ==(Object? other) =>
      identical(this, other) || (runtimeType == other?.runtimeType);
  @override
  int get hashCode => runtimeType.hashCode;
  @override
  int toOrdinal() => 3;
  @override
  String toString() => '/books';
}

class BooksDetailsRoute extends AppRoute {
  final String id;
  const BooksDetailsRoute({required this.id});
  @override
  bool operator ==(Object? other) =>
      identical(this, other) ||
      (runtimeType == other?.runtimeType &&
          other is BooksDetailsRoute &&
          id == other.id);
  @override
  int get hashCode => hashValues(runtimeType, id);
  @override
  int toOrdinal() => 4;
  @override
  String toString() => '/books/$id';
}

class SettingsRoute extends AppRoute {
  const SettingsRoute();
  @override
  bool operator ==(Object? other) =>
      identical(this, other) || (runtimeType == other?.runtimeType);
  @override
  int get hashCode => runtimeType.hashCode;
  @override
  int toOrdinal() => 5;
  @override
  String toString() => '/settings';
}

class _RoutesAtAuthorsRoute {
  final Build<AuthorsRoute> _build;
  _RoutesAtAuthorsRoute(this._build);
  _RoutesAtAuthorsRoute$ call(_Routes$ parent) =>
      _RoutesAtAuthorsRoute$(parent._state, _build);
  Object atAuthorDetailsRoute(Build build) => Object();
  Object atAuthorsBookDetailsRoute(Build build) => Object();
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
  void addAuthorDetails({required String id}) =>
      _state.add(AuthorDetailsRoute(id: id));
  void putAuthorDetails({required String id}) =>
      _state.put(AuthorDetailsRoute(id: id));
  void setAuthorDetails({required String id}) =>
      _state.set(AuthorDetailsRoute(id: id));
  void addAuthorsBookDetails(
          {required String authorId, required String bookId}) =>
      _state.add(AuthorsBookDetailsRoute(authorId: authorId, bookId: bookId));
  void putAuthorsBookDetails(
          {required String authorId, required String bookId}) =>
      _state.put(AuthorsBookDetailsRoute(authorId: authorId, bookId: bookId));
  void setAuthorsBookDetails(
          {required String authorId, required String bookId}) =>
      _state.set(AuthorsBookDetailsRoute(authorId: authorId, bookId: bookId));
}

class AuthorDetailsRoute extends AppRoute {
  final String id;
  final authors = const AuthorsRoute();
  const AuthorDetailsRoute({required this.id});
  @override
  bool operator ==(Object? other) =>
      identical(this, other) ||
      (runtimeType == other?.runtimeType &&
          other is AuthorDetailsRoute &&
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

class AuthorsBookDetailsRoute extends AppRoute {
  final String authorId;
  final String bookId;
  final authors = const AuthorsRoute();
  const AuthorsBookDetailsRoute({required this.authorId, required this.bookId});
  @override
  bool operator ==(Object? other) =>
      identical(this, other) ||
      (runtimeType == other?.runtimeType &&
          other is AuthorsBookDetailsRoute &&
          authorId == other.authorId &&
          bookId == other.bookId);
  @override
  int get hashCode => hashValues(runtimeType, authorId, bookId);
  @override
  int toOrdinal() => 1;
  @override
  List<AppRoute> toStack() => [...authors.toStack(), this];
  @override
  String toString() => '$authors/$authorId/books/$bookId';
}

class _RoutesAtBooksRoute {
  final Build<BooksRoute> _build;
  _RoutesAtBooksRoute(this._build);
  _RoutesAtBooksRoute$ call(_Routes$ parent) =>
      _RoutesAtBooksRoute$(parent._state, _build);
  _RoutesAtBookRoute atBookRoute(Build<BookRoute> build) =>
      _RoutesAtBookRoute(build);
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

class _RoutesAtBookRoute {
  final Build<BookRoute> _build;
  _RoutesAtBookRoute(this._build);
  _RoutesAtBookRoute$ call(_RoutesAtBooksRoute$ parent) =>
      _RoutesAtBookRoute$(parent._state, _build);
  _RoutesAtChapterRoute atChapterRoute(Build<ChapterRoute> build) =>
      _RoutesAtChapterRoute(build);
}

class _RoutesAtBookRoute$ {
  final AppRoutes<BookRoute> _routes;
  late final AppRouterState _state;
  _RoutesAtBookRoute$(AppRouterState parent, Build<BookRoute> build)
      : _routes = AppRoutes<BookRoute>() {
    build(_routes);
    _state = AppRouterState('_RoutesAtBookRoute', _routes, parent: parent);
  }
  ChildRouter router() => ChildRouter(
      '_RoutesAtBookRoute', () => AppRouterDelegate(_routes, _state));
  AppRoute get current => _state.last;
  void pop() => _state.pop();
  void addChapter({required String id, required BookRoute book}) =>
      _state.add(ChapterRoute(id: id, book: book));
  void putChapter({required String id, required BookRoute book}) =>
      _state.put(ChapterRoute(id: id, book: book));
  void setChapter({required String id, required BookRoute book}) =>
      _state.set(ChapterRoute(id: id, book: book));
}

class ChapterRoute extends AppRoute {
  final String id;
  final BookRoute book;
  const ChapterRoute({required this.id, required this.book});
  @override
  bool operator ==(Object? other) =>
      identical(this, other) ||
      (runtimeType == other?.runtimeType &&
          other is ChapterRoute &&
          id == other.id &&
          book == other.book);
  @override
  int get hashCode => hashValues(runtimeType, id, book);
  @override
  int toOrdinal() => 0;
  @override
  List<AppRoute> toStack() => [...book.toStack(), this];
  @override
  String toString() => '$book/$id';
}

class _RoutesAtChapterRoute {
  final Build<ChapterRoute> _build;
  _RoutesAtChapterRoute(this._build);
  _RoutesAtChapterRoute$ call(_RoutesAtBookRoute$ parent) =>
      _RoutesAtChapterRoute$(parent._state, _build);
  Object atVerseRoute(Build build) => Object();
}

class _RoutesAtChapterRoute$ {
  final AppRoutes<ChapterRoute> _routes;
  late final AppRouterState _state;
  _RoutesAtChapterRoute$(AppRouterState parent, Build<ChapterRoute> build)
      : _routes = AppRoutes<ChapterRoute>() {
    build(_routes);
    _state = AppRouterState('_RoutesAtChapterRoute', _routes, parent: parent);
  }
  ChildRouter router() => ChildRouter(
      '_RoutesAtChapterRoute', () => AppRouterDelegate(_routes, _state));
  AppRoute get current => _state.last;
  void pop() => _state.pop();
  void addVerse({required String id, required ChapterRoute chapter}) =>
      _state.add(VerseRoute(id: id, chapter: chapter));
  void putVerse({required String id, required ChapterRoute chapter}) =>
      _state.put(VerseRoute(id: id, chapter: chapter));
  void setVerse({required String id, required ChapterRoute chapter}) =>
      _state.set(VerseRoute(id: id, chapter: chapter));
}

class VerseRoute extends AppRoute {
  final String id;
  final ChapterRoute chapter;
  const VerseRoute({required this.id, required this.chapter});
  @override
  bool operator ==(Object? other) =>
      identical(this, other) ||
      (runtimeType == other?.runtimeType &&
          other is VerseRoute &&
          id == other.id &&
          chapter == other.chapter);
  @override
  int get hashCode => hashValues(runtimeType, id, chapter);
  @override
  int toOrdinal() => 0;
  @override
  List<AppRoute> toStack() => [...chapter.toStack(), this];
  @override
  String toString() => '$chapter/$id';
}
