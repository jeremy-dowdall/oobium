import 'package:flutter/widgets.dart';
import 'main3_routes.dart';

extension BuildContextX on BuildContext {
  Routes get mainRoutes => RoutesProvider.of(this).mainRoutes;
  RoutesAtAuthorsRoute get authorRoutes => RoutesProvider.of(this).authorRoutes;
  RoutesAtBooksRoute get bookRoutes => RoutesProvider.of(this).bookRoutes;
  RoutesAtBookRoute get chapterRoutes => RoutesProvider.of(this).chapterRoutes;
  RoutesAtChapterRoute get verseRoutes => RoutesProvider.of(this).verseRoutes;
}

typedef Builder = Widget Function(BuildContext context, Routes mainRoutes);

class RoutesProvider extends InheritedWidget {
  late final Routes mainRoutes;
  late final RoutesAtAuthorsRoute authorRoutes;
  late final RoutesAtBooksRoute bookRoutes;
  late final RoutesAtBookRoute chapterRoutes;
  late final RoutesAtChapterRoute verseRoutes;
  RoutesProvider({required Builder builder})
      : super(child: _RoutesProviderChild(builder)) {
    mainRoutes = mainBuilder();
    authorRoutes = authorBuilder(mainRoutes);
    bookRoutes = bookBuilder(mainRoutes);
    chapterRoutes = chapterBuilder(bookRoutes);
    verseRoutes = verseBuilder(chapterRoutes);
  }
  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => true;
  static RoutesProvider of(BuildContext context) {
    return context.findAncestorWidgetOfExactType<RoutesProvider>() ??
        (throw 'RoutesProvider not found in widget hierarchy');
  }
}

class _RoutesProviderChild extends StatelessWidget {
  final Builder builder;
  _RoutesProviderChild(this.builder);
  @override
  Widget build(BuildContext context) {
    return builder(context, context.mainRoutes);
  }
}
