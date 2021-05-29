import 'package:flutter_test/flutter_test.dart';
import 'package:oobium_routing/oobium_routing2.dart';

import 'app/routes.dart';

void main() {
  group('equals method', () {
    test('system routes', () {
      expect(HomeRoute() == HomeRoute(), isTrue);
      expect(UninitializedRoute() == UninitializedRoute(), isTrue);
    });

    test('constant route (declared non-const)', () {
      expect(AuthorsRoute() == AuthorsRoute(), isTrue);
      expect(AuthorsRoute() == BooksRoute(), isFalse);
    });

    test('constant route (declared const)', () {
      expect(const AuthorsRoute() == const AuthorsRoute(), isTrue);
      expect(const AuthorsRoute() == const BooksRoute(), isFalse);
    });

    test('variable route (declared non-const)', () {
      expect(AuthorRoute(id: '1') == AuthorRoute(id: '1'), isTrue);
      expect(AuthorRoute(id: '1') == AuthorRoute(id: '456'), isFalse);
    });

    test('variable route (declared const)', () {
      expect(const AuthorRoute(id: '1') == const AuthorRoute(id: '1'), isTrue);
      expect(const AuthorRoute(id: '1') == const AuthorRoute(id: '456'), isFalse);
    });
  });

  test('initial state - uninitialized', () {
    final main = MainRoutesTester();
    final author = AuthorRoutesTester(main);
    final book = BookRoutesTester(main);

    expect(main.state.currentGlobal, UninitializedRoute());
    expect(author.state.currentGlobal, UninitializedRoute());
    expect(book.state.currentGlobal, UninitializedRoute());

    expect(main.state.currentLocal, UninitializedRoute());
    expect(author.state.currentLocal, UninitializedRoute());
    expect(book.state.currentLocal, UninitializedRoute());

    expect(main.state.stack, []);
    expect(author.state.stack, []);
    expect(book.state.stack, []);

    expect(main.pages, []);
    expect(author.pages, []);
    expect(book.pages, []);

    expect(main.eventCount, 0);
    expect(author.eventCount, 0);
    expect(book.eventCount, 0);
  });

  group('setNewRoutePath', () {
    test('home', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);

      main.state.setNewRoutePath(HomeRoute());

      expect(main.eventCount, 1);
      expect(author.eventCount, 1);
      expect(book.eventCount, 0);

      expect(main.state.currentGlobal, AuthorsRoute());
      expect(author.state.currentGlobal, AuthorsRoute());
      expect(book.state.currentGlobal, AuthorsRoute());

      expect(main.state.currentLocal, AuthorsRoute());
      expect(author.state.currentLocal, AuthorsRoute());
      expect(book.state.currentLocal, UninitializedRoute());

      expect(main.state.stack, [AuthorsRoute()]);
      expect(author.state.stack, [AuthorsRoute()]);
      expect(book.state.stack, []);

      expect(main.pages, ['/authors']);
      expect(author.pages, ['/authors']);
      expect(book.pages, []);
    });

    test('Authors', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);

      main.state.setNewRoutePath(AuthorsRoute());

      expect(main.eventCount, 1);
      expect(author.eventCount, 1);
      expect(book.eventCount, 0);

      expect(main.state.currentGlobal, AuthorsRoute());
      expect(author.state.currentGlobal, AuthorsRoute());
      expect(book.state.currentGlobal, AuthorsRoute());

      expect(main.state.currentLocal, AuthorsRoute());
      expect(author.state.currentLocal, AuthorsRoute());
      expect(book.state.currentLocal, UninitializedRoute());

      expect(main.state.stack, [AuthorsRoute()]);
      expect(author.state.stack, [AuthorsRoute()]);
      expect(book.state.stack, []);

      expect(main.pages, ['/authors']);
      expect(author.pages, ['/authors']);
      expect(book.pages, []);
    });

    test('Author(1)', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);

      main.state.setNewRoutePath(AuthorRoute(id: '1'));

      expect(main.eventCount, 1);
      expect(author.eventCount, 1);
      expect(book.eventCount, 0);

      expect(main.state.currentGlobal, AuthorRoute(id: '1'));

      expect(main.state.currentLocal, AuthorsRoute());
      expect(author.state.currentLocal, AuthorRoute(id: '1'));
      expect(book.state.currentLocal, UninitializedRoute());

      expect(main.state.stack, [AuthorsRoute()]);
      expect(author.state.stack, [AuthorRoute(id: '1')]);
      expect(book.state.stack, []);

      expect(main.pages, ['/authors']);
      expect(author.pages, ['/authors/1']);
      expect(book.pages, []);
    });

    test('Books', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);

      main.state.setNewRoutePath(BooksRoute());

      expect(main.eventCount, 1);
      expect(author.eventCount, 0);
      expect(book.eventCount, 1);

      expect(main.state.currentGlobal, BooksRoute());
      expect(author.state.currentGlobal, BooksRoute());
      expect(book.state.currentGlobal, BooksRoute());

      expect(main.state.currentLocal, BooksRoute());
      expect(author.state.currentLocal, UninitializedRoute());
      expect(book.state.currentLocal, BooksRoute());

      expect(main.state.stack, [BooksRoute()]);
      expect(author.state.stack, []);
      expect(book.state.stack, [BooksRoute()]);

      expect(main.pages, ['/books']);
      expect(author.pages, []);
      expect(book.pages, ['/books']);
    });

    test('Book(1)', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);

      main.state.setNewRoutePath(BookRoute(id: '1'));

      expect(main.eventCount, 1);
      expect(author.eventCount, 0);
      expect(book.eventCount, 1);

      expect(main.state.currentGlobal, BookRoute(id: '1'));

      expect(main.state.currentLocal, BooksRoute());
      expect(author.state.currentLocal, UninitializedRoute());
      expect(book.state.currentLocal, BookRoute(id: '1'));

      expect(main.state.stack, [BooksRoute()]);
      expect(author.state.stack, []);
      expect(book.state.stack, [BookRoute(id: '1')]);

      expect(main.pages, ['/books']);
      expect(author.pages, []);
      expect(book.pages, ['/books/1']);
    });

    test('Book(1) -> Authors', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);

      main.state.setNewRoutePath(BookRoute(id: '1'));
      main.state.setNewRoutePath(AuthorsRoute());

      /// hard or soft set?
      /// this is typically in support of the web browser address bar and history
      ///   coming from Android, it is easy to think the browser's 'back button' deals with state, but no:
      ///     "It is just a list of urls": https://github.com/flutter/flutter/issues/71122#issuecomment-733917485
      ///   as such, setNewRoutePath is a hard-set

      expect(main.eventCount, 2);
      expect(author.eventCount, 1);
      expect(book.eventCount, 2);

      expect(main.state.currentGlobal, AuthorsRoute());
      expect(author.state.currentGlobal, AuthorsRoute());
      expect(book.state.currentGlobal, AuthorsRoute());

      expect(main.state.currentLocal, AuthorsRoute());
      expect(author.state.currentLocal, AuthorsRoute());
      expect(book.state.currentLocal, UninitializedRoute());

      expect(main.state.stack, [AuthorsRoute()]);
      expect(author.state.stack, [AuthorsRoute()]);
      expect(book.state.stack, []);

      expect(main.pages, ['/authors']);
      expect(author.pages, ['/authors']);
      expect(book.pages, []);
    });
  });

  group('add route', () {

    test('home -> addAuthors', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);
      main.routes.setNewRoutePath(HomeRoute());

      main.routes.addAuthors();

      expect(main.eventCount, 1);
      expect(author.eventCount, 1);
      expect(book.eventCount, 0);

      expect(main.state.currentGlobal, AuthorsRoute());
      expect(author.state.currentGlobal, AuthorsRoute());
      expect(book.state.currentGlobal, AuthorsRoute());

      expect(main.state.currentLocal, AuthorsRoute());
      expect(author.state.currentLocal, AuthorsRoute());
      expect(book.state.currentLocal, UninitializedRoute());

      expect(main.state.stack, [AuthorsRoute()]);
      expect(author.state.stack, [AuthorsRoute()]);
      expect(book.state.stack, []);

      expect(main.pages, ['/authors']);
      expect(author.pages, ['/authors']);
      expect(book.pages, []);
    });

    test('home -> addBooks', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);
      main.routes.setNewRoutePath(HomeRoute());

      main.routes.addBooks();

      expect(main.eventCount, 2);
      expect(author.eventCount, 1);
      expect(book.eventCount, 1);

      expect(main.state.currentGlobal, BooksRoute());
      expect(author.state.currentGlobal, BooksRoute());
      expect(book.state.currentGlobal, BooksRoute());

      expect(main.state.currentLocal, BooksRoute());
      expect(author.state.currentLocal, AuthorsRoute());
      expect(book.state.currentLocal, BooksRoute());

      expect(main.state.stack, [AuthorsRoute(), BooksRoute()]);
      expect(author.state.stack, [AuthorsRoute()]);
      expect(book.state.stack, [BooksRoute()]);

      expect(() => main.pages, throwsA(isA<DuplicateKeyException>()));
      expect(author.pages, ['/authors']);
      expect(book.pages, ['/books']);
    });

    test('home -> addBooks -> addBook(1)', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);
      main.routes.setNewRoutePath(HomeRoute());

      main.routes.addBooks();
      book.routes.addBook(id: '1');

      expect(main.eventCount, 3);
      expect(author.eventCount, 1);
      expect(book.eventCount, 2);

      expect(main.state.currentGlobal, BookRoute(id: '1'));

      expect(main.state.currentLocal, BooksRoute());
      expect(author.state.currentLocal, AuthorsRoute());
      expect(book.state.currentLocal, BookRoute(id: '1'));

      expect(main.state.stack, [AuthorsRoute(), BooksRoute()]);
      expect(author.state.stack, [AuthorsRoute()]);
      expect(book.state.stack, [BooksRoute(), BookRoute(id: '1')]);

      expect(() => main.pages, throwsA(isA<DuplicateKeyException>()));
      expect(author.pages, ['/authors']);
      expect(book.pages, ['/books', '/books/1']);
    });

    test('home -> addBooks -> addBook(1) -> addAuthors', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);
      main.routes.setNewRoutePath(HomeRoute());

      main.routes.addBooks();
      book.routes.addBook(id: '1');
      main.routes.addAuthors();

      /// cycles are not allowed in the stack
      ///   so if we add/put/set a route that already exists, we roll back
      ///   add/put/set do not reset children, pop does (I think...)

      expect(main.eventCount, 4);
      expect(author.eventCount, 1);
      expect(book.eventCount, 2);

      expect(main.state.currentGlobal, AuthorsRoute());
      expect(author.state.currentGlobal, AuthorsRoute());
      expect(book.state.currentGlobal, AuthorsRoute());

      expect(main.state.currentLocal, AuthorsRoute());
      expect(author.state.currentLocal, AuthorsRoute());
      expect(book.state.currentLocal, BookRoute(id: '1'));

      expect(main.state.stack, [AuthorsRoute()]);
      expect(author.state.stack, [AuthorsRoute()]);
      expect(book.state.stack, [BooksRoute(), BookRoute(id: '1')]);

      expect(main.pages, ['/authors']);
      expect(author.pages, ['/authors']);
      expect(book.pages, ['/books', '/books/1']);
    });

    test('home -> addBooks -> addBook(1) -> putAuthors', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);
      main.routes.setNewRoutePath(HomeRoute());

      main.routes.addBooks();
      book.routes.addBook(id: '1');
      main.routes.putAuthors();

      /// cycles are not allowed in the stack
      ///   so if we add/put/set a route that already exists, we roll back
      ///   add/put/set do not reset children, pop does (I think...)

      expect(main.eventCount, 4);
      expect(author.eventCount, 1);
      expect(book.eventCount, 2);

      expect(main.state.currentGlobal, AuthorsRoute());
      expect(author.state.currentGlobal, AuthorsRoute());
      expect(book.state.currentGlobal, AuthorsRoute());

      expect(main.state.currentLocal, AuthorsRoute());
      expect(author.state.currentLocal, AuthorsRoute());
      expect(book.state.currentLocal, BookRoute(id: '1'));

      expect(main.state.stack, [AuthorsRoute()]);
      expect(author.state.stack, [AuthorsRoute()]);
      expect(book.state.stack, [BooksRoute(), BookRoute(id: '1')]);

      expect(main.pages, ['/authors']);
      expect(author.pages, ['/authors']);
      expect(book.pages, ['/books', '/books/1']);
    });

    test('home -> addBooks -> addBook(1) -> setAuthors', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);
      main.routes.setNewRoutePath(HomeRoute());

      main.routes.addBooks();
      book.routes.addBook(id: '1');
      main.routes.putAuthors();

      /// cycles are not allowed in the stack
      ///   so if we add/put/set a route that already exists, we roll back
      ///   add/put/set do not reset children, pop does (I think...)

      expect(main.eventCount, 4);
      expect(author.eventCount, 1);
      expect(book.eventCount, 2);

      expect(main.state.currentGlobal, AuthorsRoute());
      expect(author.state.currentGlobal, AuthorsRoute());
      expect(book.state.currentGlobal, AuthorsRoute());

      expect(main.state.currentLocal, AuthorsRoute());
      expect(author.state.currentLocal, AuthorsRoute());
      expect(book.state.currentLocal, BookRoute(id: '1'));

      expect(main.state.stack, [AuthorsRoute()]);
      expect(author.state.stack, [AuthorsRoute()]);
      expect(book.state.stack, [BooksRoute(), BookRoute(id: '1')]);

      expect(main.pages, ['/authors']);
      expect(author.pages, ['/authors']);
      expect(book.pages, ['/books', '/books/1']);
    });

    test('home -> addBooks -> addBook(1) -> main.pop', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);
      main.routes.setNewRoutePath(HomeRoute());

      main.routes.addBooks();
      book.routes.addBook(id: '1');
      main.routes.pop();

      /// cycles are not allowed in the stack
      ///   so if we add/put/set a route that already exists, we roll back
      ///   add/put/set do not reset children, pop does (I think...)

      expect(main.eventCount, 4);
      expect(author.eventCount, 1);
      expect(book.eventCount, 2);

      expect(main.state.currentGlobal, AuthorsRoute());
      expect(author.state.currentGlobal, AuthorsRoute());
      expect(book.state.currentGlobal, AuthorsRoute());

      expect(main.state.currentLocal, AuthorsRoute());
      expect(author.state.currentLocal, AuthorsRoute());
      expect(book.state.currentLocal, UninitializedRoute());

      expect(main.state.stack, [AuthorsRoute()]);
      expect(author.state.stack, [AuthorsRoute()]);
      expect(book.state.stack, []);

      expect(main.pages, ['/authors']);
      expect(author.pages, ['/authors']);
      expect(book.pages, []);
    });
  });
}
