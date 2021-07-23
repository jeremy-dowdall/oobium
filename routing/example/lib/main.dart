import 'package:flutter/material.dart';
import 'package:oobium_routing_example/main_routes.g.provider.dart';

import 'main_routes.dart';

void main() => runApp(
  RoutesProvider(
    builder: (_, mainRoutes) => MaterialApp.router(
      title: 'NavDemo',
      routeInformationParser: mainRoutes.createRouteParser(),
      routerDelegate: mainRoutes.createRouterDelegate()
    ),
  )
);

///
/// UI
///
class HomeScreen extends StatelessWidget {

  const HomeScreen();

  @override
  Widget build(BuildContext context) {
    final routeIndex = context.mainRoutes.current.toOrdinal();
    return Scaffold(
      appBar: AppBar(title: Text('Home'),),
      body:
        (routeIndex == 0) ? context.authorRoutes() :
        (routeIndex == 1) ? context.bookRoutes()
        : SettingsView(),
      bottomNavigationBar: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Authors'),
            BottomNavigationBarItem(icon: Icon(Icons.local_library), label: 'Books'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          ],
          currentIndex: routeIndex,
          onTap: (index) => context.mainRoutes.setFromOrdinal(index)
      ),
    );
  }
}

class AuthorsView extends StatelessWidget {

  const AuthorsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
        children: authors.keys.map((id) {
          final author = authors[id]!;
          return ListTile(
            title: Text(author.name),
            onTap: () => context.authorRoutes.addAuthor(id: id),
          );
        }).toList()
    );
  }
}

class AuthorView extends StatelessWidget {

  final String id;
  const AuthorView(this.id);

  @override
  Widget build(BuildContext context) {
    final author = authors[id]!;
    return Center(child: Column(children: [
      Text('Name: ${author.name}'),
      ElevatedButton.icon(
        icon: Icon(Icons.arrow_back),
        label: Text('Back'),
        onPressed: () => context.authorRoutes.pop(),
      ),
    ],),);
  }
}

class BooksView extends StatelessWidget {

  const BooksView();

  @override
  Widget build(BuildContext context) {
    return ListView(
        children: books.keys.map((id) {
          final book = books[id]!;
          return ListTile(
            title: Text(book.title),
            subtitle: Text(book.author),
            onTap: () => context.bookRoutes.addBook(id: id),
          );
        }).toList()
    );
  }
}

class BookView extends StatelessWidget {

  final String id;
  const BookView(this.id);

  @override
  Widget build(BuildContext context) {
    final book = books[id]!;
    return Center(child: Column(children: [
      Text('Title: ${book.title}'),
      Text('Author: ${book.author}'),
      ElevatedButton.icon(
        icon: Icon(Icons.arrow_back),
        label: Text('Back'),
        onPressed: () => context.bookRoutes.pop(),
      ),
    ],),);
  }
}

class SettingsView extends StatelessWidget {

  const SettingsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Settings Screen'),
          ElevatedButton.icon(
            icon: Icon(Icons.person),
            label: Text(authors['1']!.name),
            onPressed: () => context.mainRoutes.setNewRoutePath(AuthorRoute(id: '1')),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.local_library),
            label: Text(books['1']!.title),
            onPressed: () => context.mainRoutes.setNewRoutePath(BookRoute(id: '1')),
          ),
        ],
      )
    );
  }
}


///
/// DATA
///
final Map<String, Author> authors = {
  '0': Author('Robert A. Heinlein'),
  '1': Author('Isaac Asimov'),
  '2': Author('Ray Bradbury'),
};

final Map<String, Book> books = {
  '0': Book('Stranger in a Strange Land', 'Robert A. Heinlein'),
  '1': Book('Foundation', 'Isaac Asimov'),
  '2': Book('Fahrenheit 451', 'Ray Bradbury'),
};

class Author {
  final String name;
  Author(this.name);
}

class Book {
  final String title;
  final String author;
  Book(this.title, this.author);
}
