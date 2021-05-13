import 'package:flutter/material.dart';
import 'package:oobium_routing/oobium_routing2.dart';

part 'main3_routes.g.dart';

// class AuthState extends AppRouterState {
//   bool anonymous = true;
// }

final mainBuilder = _Routes((r) => r
  ..redirect('/old_path/<var1>/first/<var2>', '/new_path/<var2>/second/<var1>/<var3>')
  ..page<AuthRoute>('/sign_in', (_,__) => MaterialPage(child: Text('auth page')),
    // onGuard: (_,__) => !context.state.anonymous ? const HomeRoute() : null,
  )
  ..guard(
    onGuard: (state) => null, // state.anonymous ? const AuthRoute() : null,
    guarded: (guarded) => guarded
      ..view<AuthorsRoute>('/authors', (_,__) => Text('authors page'))
      ..view<AuthorsDetailsRoute>('/authors/<id>', (_,__) => Text('authors page'))
      ..page<BooksRoute>('/books', (_,__) => MaterialPage(child: Text('books page')))
      ..page<BooksDetailsRoute>('/books/<id>', (_,__) => MaterialPage(child: Text('books page')))
      ..page<SettingsRoute>('/settings', (_,__) => MaterialPage(child: Text('settings page')))
  )
);

final authorBuilder = mainBuilder.atAuthorsRoute((r) => r
  ..view<AuthorDetailsRoute>('/<id>', (_,r) => Text('author details page(${r.id})'))
  ..page<AuthorsBookDetailsRoute>('/<authorId>/books/<bookId>', (_,r) => MaterialPage(child: Text('author ${r.authorId} details page(${r.bookId})')))
);

final bookBuilder = mainBuilder.atBooksRoute((r) => r
  ..page<BookRoute>('/<id>', (_,r) => MaterialPage(child: Text('book details page${r.id}')))
);
final chapterBuilder = bookBuilder.atBookRoute((r) => r
  ..page<ChapterRoute>('/<id>', (_,r) => MaterialPage(child: Text('book details page${r.id}')))
);
final verseBuilder = chapterBuilder.atChapterRoute((r) => r
  ..page<VerseRoute>('/<id>', (_,r) => MaterialPage(child: Text('book details page${r.id}')))
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