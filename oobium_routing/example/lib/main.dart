import 'package:flutter/material.dart';
import 'package:oobium_routing/oobium_routing.dart';

void main() => runApp(MaterialApp.router(
    title: 'NavDemo',
    routeInformationParser: routes.createRouteParser(),
    routerDelegate: routes.createRouterDelegate()
));

///
/// Routes
///
class AuthorsRoute extends AppRoute { }
class AuthorsListRoute extends AppRoute { }
class AuthorsDetailRoute extends AppRoute { AuthorsDetailRoute(String id) : super({'id': id}); }
class BooksRoute extends AppRoute { }
class BooksListRoute extends AppRoute { }
class BooksDetailRoute extends AppRoute { BooksDetailRoute(String id) : super({'id': id}); }
class SettingsRoute extends AppRoute { }

final routes = AppRoutes()
  ..add<AuthorsRoute>(
      path: '/authors',
      onParse: (data) => AuthorsRoute(),
      onBuild: (route) => [HomePage()],
      children: AppRoutes()
        ..add<AuthorsListRoute>(
            path: '/',
            onParse: (data) => AuthorsListRoute(),
            onBuild: (route) => [AuthorsListPage()]
        )
        ..add<AuthorsDetailRoute>(
            path: '/<id>',
            onParse: (data) => AuthorsDetailRoute(data['id']),
            onBuild: (route) => [AuthorsListPage(), AuthorsDetailPage(route['id'])]
        )
  )
  ..add<BooksRoute>(
      path: '/books',
      onParse: (data) => BooksRoute(),
      onBuild: (route) => [HomePage()],
      children: AppRoutes()
        ..add<BooksListRoute>(
            path: '/',
            onParse: (data) => BooksListRoute(),
            onBuild: (route) => [BooksListPage()]
        )
        ..add<BooksDetailRoute>(
            path: '/<id>',
            onParse: (data) => BooksDetailRoute(data['id']),
            onBuild: (route) => [BooksListPage(), BooksDetailPage(route['id'])]
        )
  )
  ..add<SettingsRoute>(
      path: '/settings',
      onParse: (data) => SettingsRoute(),
      onBuild: (route) => [HomePage()]
  )
;


///
/// UI
///
class HomePage extends Page {

  HomePage() : super(key: ValueKey('/'));

  @override
  Route createRoute(BuildContext context) {
    return MaterialPageRoute(
        settings: this,
        builder: (context) => HomeScreen()
    );
  }
}

class HomeScreen extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    final index = getIndex(context.route);
    return Scaffold(
      appBar: AppBar(title: Text('Home'),),
      body: IndexedStack(
        index: index,
        children: [
          ChildRouter<AuthorsRoute>(),
          ChildRouter<BooksRoute>(),
          SettingsView()
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Authors'),
            BottomNavigationBarItem(icon: Icon(Icons.local_library), label: 'Books'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          ],
          currentIndex: index,
          onTap: (index) => context.route = getRoute(index)
      ),
    );
  }

  int getIndex(AppRoute route) {
    switch(route.runtimeType) {
      case AuthorsRoute: return 0;
      case BooksRoute: return 1;
      case SettingsRoute: return 2;
    }
    throw Exception('unhandled route: $route');
  }

  AppRoute getRoute(int index) {
    switch(index) {
      case 0: return AuthorsRoute();
      case 1: return BooksRoute();
      case 2: return SettingsRoute();
    }
    throw Exception('unhandled index: $index');
  }
}

class AuthorsListPage extends Page {

  AuthorsListPage() : super(key: ValueKey('/authors'));

  @override
  Route createRoute(BuildContext context) {
    return MaterialPageRoute(
        settings: this,
        builder: (context) => AuthorsListView()
    );
  }
}

class AuthorsListView extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return ListView(
        children: authors.keys.map((id) {
          final author = authors[id];
          return ListTile(
            title: Text(author.name),
            onTap: () => context.route = AuthorsDetailRoute(id),
          );
        }).toList()
    );
  }
}

class AuthorsDetailPage extends Page {

  final String id;
  AuthorsDetailPage(this.id) : super(key: ValueKey('/authors/$id'));

  @override
  Route createRoute(BuildContext context) {
    return MaterialPageRoute(
        settings: this,
        builder: (context) => AuthorsDetailView(id)
    );
  }
}

class AuthorsDetailView extends StatelessWidget {

  final String id;
  AuthorsDetailView(this.id);

  @override
  Widget build(BuildContext context) {
    final author = authors[id];
    return Center(child: Column(children: [
      Text('Name: ${author.name}'),
      ElevatedButton.icon(
        icon: Icon(Icons.arrow_back),
        label: Text('Back'),
        onPressed: () => Navigator.pop(context),
      ),
    ],),);
  }
}

class BooksListPage extends Page {

  BooksListPage() : super(key: ValueKey('/books'));

  @override
  Route createRoute(BuildContext context) {
    return MaterialPageRoute(
        settings: this,
        builder: (context) => BooksListView()
    );
  }
}

class BooksListView extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return ListView(
        children: books.keys.map((id) {
          final book = books[id];
          return ListTile(
            title: Text(book.title),
            subtitle: Text(book.author),
            onTap: () => context.route = BooksDetailRoute(id),
          );
        }).toList()
    );
  }
}

class BooksDetailPage extends Page {

  final String id;
  BooksDetailPage(this.id) : super(key: ValueKey('/books/$id'));

  @override
  Route createRoute(BuildContext context) {
    return MaterialPageRoute(
        settings: this,
        builder: (context) => BooksDetailView(id)
    );
  }
}

class BooksDetailView extends StatelessWidget {

  final String id;
  BooksDetailView(this.id);

  @override
  Widget build(BuildContext context) {
    final book = books[id];
    return Center(child: Column(children: [
      Text('Title: ${book.title}'),
      Text('Author: ${book.author}'),
      ElevatedButton.icon(
        icon: Icon(Icons.arrow_back),
        label: Text('Back'),
        onPressed: () => Navigator.pop(context),
      ),
    ],),);
  }
}

class SettingsPage extends Page {

  SettingsPage() : super(key: ValueKey('/settings'));

  @override
  Route createRoute(BuildContext context) {
    return MaterialPageRoute(
        settings: this,
        builder: (context) => SettingsView()
    );
  }
}

class SettingsView extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Settings Screen'));
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
