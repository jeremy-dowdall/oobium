import 'package:flutter_test/flutter_test.dart';
import 'package:oobium_routing/oobium_routing.dart';

import 'app/main.dart';
import 'app/routes.dart';

void main() {
  testWidgets('initial state - uninitialized', (tester) async {
    final app = createMaterialApp();
    await tester.pumpWidget(app);
    expect(find.text('TODO authors'), findsNothing);
  });

  group('setNewPath', () {
    testWidgets('home', (tester) async {
      final app = createMaterialApp();
      await tester.pumpWidget(app);
      app.mainRoutes.setNewRoutePath(HomeRoute());
      await tester.pump();
      for(final author in authors.values) {
        expect(find.text(author.name), findsOneWidget);
      }
      for(final book in books.values) {
        expect(find.text(book.title), findsNothing);
      }
    });

    testWidgets('Authors', (tester) async {
      final app = createMaterialApp();
      await tester.pumpWidget(app);
      app.mainRoutes.setNewRoutePath(AuthorsRoute());
      await tester.pump();
      for(final author in authors.values) {
        expect(find.text(author.name), findsOneWidget);
      }
      for(final book in books.values) {
        expect(find.text(book.title), findsNothing);
      }
    });

    testWidgets('Author(1)', (tester) async {
      final app = createMaterialApp();
      await tester.pumpWidget(app);
      app.mainRoutes.setNewRoutePath(AuthorRoute(id: '1'));
      await tester.pump();
      expect(find.text(authors['0']!.name), findsNothing);
      expect(find.text(authors['1']!.name), findsOneWidget);
      expect(find.text(authors['0']!.name), findsNothing);
      for(final book in books.values) {
        expect(find.text(book.title), findsNothing);
      }
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('Books', (tester) async {
      final app = createMaterialApp();
      await tester.pumpWidget(app);
      app.mainRoutes.setNewRoutePath(BooksRoute());
      await tester.pump();
      for(final author in authors.values) {
        expect(find.text(author.name), findsNothing);
      }
      for(final book in books.values) {
        expect(find.text(book.title), findsOneWidget);
      }
    });

    testWidgets('Book(1)', (tester) async {
      final app = createMaterialApp();
      await tester.pumpWidget(app);
      app.mainRoutes.setNewRoutePath(BookRoute(id: '1'));
      await tester.pump();
      for(final author in authors.values) {
        expect(find.text(author.name), findsNothing);
      }
      expect(find.text(books['0']!.title), findsNothing);
      expect(find.text(books['1']!.title), findsOneWidget);
      expect(find.text(books['0']!.title), findsNothing);
      expect(find.text('Back'), findsOneWidget);
    });
  });

  group('add route', () {
    testWidgets('home -> addAuthors', (tester) async {
      final app = createMaterialApp();
      await tester.pumpWidget(app);
      app.mainRoutes.setNewRoutePath(HomeRoute());
      await tester.pump();
      app.mainRoutes.addAuthors();
      await tester.pump();
      for(final author in authors.values) {
        expect(find.text(author.name), findsOneWidget);
      }
      for(final book in books.values) {
        expect(find.text(book.title), findsNothing);
      }
    });
    testWidgets('home -> addBooks', (tester) async {
      final app = createMaterialApp();
      await tester.pumpWidget(app);
      app.mainRoutes.setNewRoutePath(HomeRoute());
      await tester.pump();
      app.mainRoutes.addBooks();
      await tester.pump();
      expect(tester.takeException(), isA<DuplicateKeyException>());
    });
  });

  group('set route', () {
    testWidgets('home -> setAuthors', (tester) async {
      final app = createMaterialApp();
      await tester.pumpWidget(app);
      app.mainRoutes.setNewRoutePath(HomeRoute());
      await tester.pump();
      app.mainRoutes.setAuthors();
      await tester.pump();
      for(final author in authors.values) {
        expect(find.text(author.name), findsOneWidget);
      }
      for(final book in books.values) {
        expect(find.text(book.title), findsNothing);
      }
    });
    testWidgets('home -> setBooks', (tester) async {
      final app = createMaterialApp();
      await tester.pumpWidget(app);
      app.mainRoutes.setNewRoutePath(HomeRoute());
      await tester.pump();
      app.mainRoutes.setBooks();
      await tester.pump();
      for(final author in authors.values) {
        expect(find.text(author.name), findsNothing);
      }
      for(final book in books.values) {
        expect(find.text(book.title), findsOneWidget);
      }
    });
  });
}
