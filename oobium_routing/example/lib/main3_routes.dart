import 'package:flutter/material.dart';
import 'package:oobium_routing/oobium_routing2.dart';

part 'main3_routes.g.dart';

// class AuthState extends AppRouterState {
//   bool anonymous = true;
// }

final mainBuilder = _Routes((r) => r
  ..redirect('/old_path/<var1>/first/<var2>', '/new_path/<var2>/second/<var1>/<var3>')
  ..page<AuthRoute>('/sign_in', (_) => MaterialPage(child: Text('auth page')),
    // onGuard: (_) => !context.state.anonymous ? const HomeRoute() : null,
  )
  ..guard(
    onGuard: (state) => null, // state.anonymous ? const AuthRoute() : null,
    guarded: (guarded) => guarded
      ..view<AuthorsRoute>('/authors', (_) => Text('authors page'))
      ..view<AuthorsDetailsRoute>('/authors/<id>', (_) => Text('authors page'))
      ..page<BooksRoute>('/books', (_) => MaterialPage(child: Text('books page')))
      ..page<BooksDetailsRoute>('/books/<id>', (_) => MaterialPage(child: Text('books page')))
      ..page<SettingsRoute>('/settings', (_) => MaterialPage(child: Text('settings page')))
  )
);

final authorBuilder = mainBuilder.atAuthorsRoute((r) => r
  ..view<AuthorDetailsRoute>('/<id>', (s) => Text('author details page(${s.route.id})'))
  ..page<AuthorsBookDetailsRoute>('/<authorId>/books/<bookId>', (s) => MaterialPage(child: Text('author ${s.route.authorId} details page(${s.route.bookId})')))
);

final bookBuilder = mainBuilder.atBooksRoute((r) => r
  ..page<BookRoute>('/<id>', (s) => MaterialPage(child: Text('book details page${s.route.id}')))
);
final chapterBuilder = bookBuilder.atBookRoute((r) => r
  ..page<ChapterRoute>('/<id>', (s) => MaterialPage(child: Text('book details page${s.route.id}')))
);
final verseBuilder = chapterBuilder.atChapterRoute((r) => r
  ..page<VerseRoute>('/<id>', (s) => MaterialPage(child: Text('book details page${s.route.id}')))
);

final mainRoutes = mainBuilder();
final authorRoutes = authorBuilder(mainRoutes);
final bookRoutes = bookBuilder(mainRoutes);
final chapterRoutes = chapterBuilder(bookRoutes);
final verseRoutes = verseBuilder(chapterRoutes);

void test() {
  // verseRoutes.addVerse(id: '123', chapter: ChapterRoute(id: '234', book: BookRoute(id: '345')));
  // final chapter = chapterRoutes.current as ChapterRoute;
  // verseRoutes.addVerse(id: '123', chapter: chapter);
  // verseRoutes.addVerse(id: '123');
}