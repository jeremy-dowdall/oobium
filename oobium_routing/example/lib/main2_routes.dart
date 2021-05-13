import 'package:flutter/material.dart';
import 'package:oobium_routing/oobium_routing2.dart';
import 'package:oobium_routing_example/main2.dart';

part 'main2_routes.g.dart';

final mainBuilder = _Routes((r) => r
  ..home(show: (_) => const AuthorsRoute())
  ..page<AuthorsRoute>('/authors', (_,__) => const AppPage('/', HomeScreen()))
  ..page<BooksRoute>('/books', (_,__) => const AppPage('/', HomeScreen()))
  ..page<SettingsRoute>('/settings', (_,__) => const AppPage('/', HomeScreen()))
);

final authorBuilder = mainBuilder.atAuthorsRoute((r) => r
  ..home(view: (_,__) => const AuthorsView())
  ..view<AuthorRoute>('/<id>', (_,r) => AuthorView(r.id))
);

final bookBuilder = mainBuilder.atBooksRoute((r) => r
  ..home(view: (_,__) => BooksView())
  ..view<BookRoute>('/<id>', (_,r) => BookView(r.id))
);

final mainRoutes = mainBuilder();
final authorRoutes = authorBuilder(mainRoutes);
final bookRoutes = bookBuilder(mainRoutes);