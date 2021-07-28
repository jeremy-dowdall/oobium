import 'package:flutter/material.dart';
import 'package:oobium_routing/oobium_routing.dart';
import 'package:oobium_routing_example/main.dart';

part 'main_routes.g.dart';

const genProvider = true;

final mainBuilder = _Routes((r) => r
  ..home(show: () => const AuthorsRoute())
  ..page<AuthorsRoute>('/authors', (_) => const AppPage('/', HomeScreen()))
  ..page<BooksRoute>('/books', (_) => const AppPage('/', HomeScreen()))
  ..page<SettingsRoute>('/settings', (_) => const AppPage('/', HomeScreen()))
);

final authorBuilder = mainBuilder.atAuthorsRoute((r) => r
  ..home(view: (_) => const AuthorsView())
  ..view<AuthorRoute>('/<id>', (s) => AuthorView(s.route.id))
);

final bookBuilder = mainBuilder.atBooksRoute((r) => r
  ..home(view: (_) => BooksView())
  ..view<BookRoute>('/<id>', (s) => BookView(s.route.id))
);
