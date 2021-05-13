import 'package:flutter_test/flutter_test.dart';
import 'package:oobium_routing/oobium_routing2.dart';

import 'app/routes.dart';

void main() {
  group('generated equals method', () {
    test('constant route (declared non-const)', () {
      expect(AuthorsRoute() == AuthorsRoute(), isTrue);
      expect(AuthorsRoute() == BooksRoute(), isFalse);
    });

    test('constant route (declared const)', () {
      expect(const AuthorsRoute() == const AuthorsRoute(), isTrue);
      expect(const AuthorsRoute() == const BooksRoute(), isFalse);
    });

    test('variable route (declared non-const)', () {
      expect(AuthorRoute(id: '123') == AuthorRoute(id: '123'), isTrue);
      expect(AuthorRoute(id: '123') == AuthorRoute(id: '456'), isFalse);
    });

    test('variable route (declared const)', () {
      expect(const AuthorRoute(id: '123') == const AuthorRoute(id: '123'), isTrue);
      expect(const AuthorRoute(id: '123') == const AuthorRoute(id: '456'), isFalse);
    });
  });

  group('setNewRoutePath', () {
    test('initial state - uninitialized', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);

      expect(main.state.current, UninitializedRoute());

      expect(main.state.last, UninitializedRoute());
      expect(author.state.last, UninitializedRoute());
      expect(book.state.last, UninitializedRoute());

      expect(main.state.stack, []);
      expect(author.state.stack, []);
      expect(book.state.stack, []);

      expect(main.pages, []);
      expect(author.pages, []);
      expect(book.pages, []);
    });

    test('home', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);

      main.state.setNewRoutePath(HomeRoute());

      expect(main.state.current, AuthorsRoute());

      expect(main.state.last, AuthorsRoute());
      expect(author.state.last, AuthorsRoute());
      expect(book.state.last, UninitializedRoute());

      expect(main.state.stack, [AuthorsRoute()]);
      expect(author.state.stack, [AuthorsRoute()]);
      expect(book.state.stack, []);

      expect(main.pages, ['/authors']);
      expect(author.pages, ['/authors']);
      expect(book.pages, []);
    });

    test('/authors', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);

      main.state.setNewRoutePath(AuthorsRoute());

      expect(main.state.current, AuthorsRoute());

      expect(main.state.last, AuthorsRoute());
      expect(author.state.last, AuthorsRoute());
      expect(book.state.last, UninitializedRoute());

      expect(main.state.stack, [AuthorsRoute()]);
      expect(author.state.stack, [AuthorsRoute()]);
      expect(book.state.stack, []);

      expect(main.pages, ['/authors']);
      expect(author.pages, ['/authors']);
      expect(book.pages, []);
    });

    test('/authors/123', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);

      main.state.setNewRoutePath(AuthorRoute(id: '123'));

      expect(main.state.current, AuthorRoute(id: '123'));

      expect(main.state.last, AuthorsRoute());
      expect(author.state.last, AuthorRoute(id: '123'));
      expect(book.state.last, UninitializedRoute());

      expect(main.state.stack, [AuthorsRoute()]);
      expect(author.state.stack, [AuthorRoute(id: '123')]);
      expect(book.state.stack, []);

      expect(main.pages, ['/authors']);
      expect(author.pages, ['/authors/123']);
      expect(book.pages, []);
    });

    test('/books', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);

      main.state.setNewRoutePath(BooksRoute());

      expect(main.state.current, BooksRoute());

      expect(main.state.last, BooksRoute());
      expect(author.state.last, UninitializedRoute());
      expect(book.state.last, BooksRoute());

      expect(main.state.stack, [BooksRoute()]);
      expect(author.state.stack, []);
      expect(book.state.stack, [BooksRoute()]);

      expect(main.pages, ['/books']);
      expect(author.pages, []);
      expect(book.pages, ['/books']);
    });

    test('/books/123', () {
      final main = MainRoutesTester();
      final author = AuthorRoutesTester(main);
      final book = BookRoutesTester(main);

      main.state.setNewRoutePath(BookRoute(id: '123'));

      expect(main.state.current, BookRoute(id: '123'));

      expect(main.state.last, BooksRoute());
      expect(author.state.last, UninitializedRoute());
      expect(book.state.last, BookRoute(id: '123'));

      expect(main.state.stack, [BooksRoute()]);
      expect(author.state.stack, []);
      expect(book.state.stack, [BookRoute(id: '123')]);

      expect(main.pages, ['/books']);
      expect(author.pages, []);
      expect(book.pages, ['/books/123']);
    });
  });
}
