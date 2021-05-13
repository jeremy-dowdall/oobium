import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

extension BuildContextX on BuildContext {

  // Router get router => Router.of(this);
  // AppRoute get route => (router.routerDelegate as AppRouterDelegate).state.last;
  // set route(AppRoute value) => (router.routerDelegate as AppRouterDelegate).state.set(value);
  // void pushRoute(AppRoute value) => (router.routerDelegate as AppRouterDelegate).state.push(value);
  // void popRoute() => (router.routerDelegate as AppRouterDelegate).state.pop();
  // set newRoutePath(AppRoute value) => router.routerDelegate.setNewRoutePath(value);
}

typedef HomeRedirect = AppRoute Function(AppRouterState state);
typedef GuardFunction<T extends AppRoute> = AppRoute? Function(AppRouterState state, T route);
typedef PopFunction<T extends AppRoute> = void Function(AppRouterState state, T route);
typedef PageBuilder<T extends AppRoute> = Page Function(AppRouterState state, T route);
typedef ViewBuilder<T extends AppRoute> = Widget Function(AppRouterState state, T route);

class AppRoutes<H extends AppRoute> {

  final RouteDefinitions definitions;
  final Map<String, dynamic> parsers;
  AppRoutes([Map<String, dynamic>? parsers]) :
    definitions = RouteDefinitions(),
    parsers = parsers ?? {};

  Type get _homeType => H;
  HomeRedirect? _homeRedirect;
  var _homeDefinition = RouteDefinition<H>();
  var _notFoundDefinition = RouteDefinition<NotFoundRoute>();
  var _errorDefinition = RouteDefinition<ErrorRoute>();

  void home({
    HomeRedirect? show,
    PageBuilder<H>? page,
    ViewBuilder<H>? view,
  }) {
    if(show != null) _homeRedirect = show;
    if(page != null) _homeDefinition = RouteDefinition<H>(onPage: page);
    if(view != null) _homeDefinition = RouteDefinition<H>(onView: view);
  }

  void notFound({
    PageBuilder<NotFoundRoute>? page,
    ViewBuilder<NotFoundRoute>? view,
  }) {
    if(page != null) _notFoundDefinition = RouteDefinition<NotFoundRoute>(onPage: page);
    if(view != null) _notFoundDefinition = RouteDefinition<NotFoundRoute>(onView: view);
  }

  void error({
    PageBuilder<ErrorRoute>? page,
    ViewBuilder<ErrorRoute>? view,
  }) {
    if(page != null) _errorDefinition = RouteDefinition<ErrorRoute>(onPage: page);
    if(view != null) _errorDefinition = RouteDefinition<ErrorRoute>(onView: view);
  }

  void page<T extends AppRoute>(String path, PageBuilder<T> onBuild, {
    GuardFunction<T>? onGuard,
    PopFunction? onPop,
  }) {
    definitions.add<T>(onPage: onBuild, onGuard: onGuard, onPop: onPop);
  }

  void redirect(String from, String to) {
    // nothing to do (everything is generated)
  }

  void orElse(ViewBuilder<NotFoundRoute> onBuild) {
    definitions.add<NotFoundRoute>(onView: onBuild);
  }

  void orError(ViewBuilder<ErrorRoute> onBuild) {
    definitions.add<ErrorRoute>(onView: onBuild);
  }

  void view<T extends AppRoute>(String path, ViewBuilder<T> onBuild, {
    GuardFunction<T>? onGuard,
    PopFunction<T>? onPop
  }) {
    definitions.add<T>(onView: onBuild, onGuard: onGuard, onPop: onPop);
  }

  GuardedRoutes guard({
    required AppRoute? Function(AppRouterState state) onGuard,
    Function(GuardedRoutes routes)? guarded
  }) {
    final guardedRoutes = GuardedRoutes(this, onGuard);
    guarded?.call(guardedRoutes);
    return guardedRoutes;
  }

  RouteDefinition definitionOf(AppRoute route) {
    final type = route.runtimeType;
    if(type == _homeType) {
      return _homeDefinition;
    }
    switch(type) {
      case HomeRoute: return _homeDefinition;
      case NotFoundRoute: return _notFoundDefinition;
      case ErrorRoute: return _errorDefinition;
    }
    assert(definitions.isSet(type), '$type not found');
    return definitions.get(type);
  }
}

class GuardedRoutes {
  final AppRoutes routes;
  final AppRoute? Function(AppRouterState state) onGuard;
  GuardedRoutes(this.routes, this.onGuard);

  void page<T extends AppRoute>(String path, PageBuilder<T> onBuild, {
    GuardFunction<T>? onGuard
  }) {
    routes.page<T>(path, onBuild, onGuard: (state, route) {
      return this.onGuard(state) ?? onGuard?.call(state, route);
    });
  }

  void view<T extends AppRoute>(String path, ViewBuilder<T> onBuild, {
    GuardFunction<T>? onGuard,
  }) {
    routes.view<T>(path, onBuild, onGuard: (state, route) {
      return this.onGuard(state) ?? onGuard?.call(state, route);
    });
  }
}

class RouteDefinitions {

  final definitions = <Type, RouteDefinition>{};

  void add<T extends AppRoute>({
    PageBuilder<T>? onPage,
    ViewBuilder<T>? onView,
    GuardFunction<T>? onGuard,
    PopFunction<T>? onPop
  }) {
    assert(isNotSet(T), 'duplicate route: $T');
    definitions[T] = RouteDefinition<T>(onPage: onPage, onView: onView, onGuard: onGuard, onPop: onPop);
  }

  void addIfNotSet<T extends AppRoute>({
    PageBuilder<T>? onPage,
    ViewBuilder<T>? onView,
    GuardFunction<T>? onGuard,
    PopFunction<T>? onPop
  }) {
    if(isNotSet(T)) {
      definitions[T] = RouteDefinition<T>(onPage: onPage, onView: onView, onGuard: onGuard, onPop: onPop);
    }
  }

  bool isSet(Type type) => definitions.containsKey(type);
  bool isNotSet(Type type) => !isSet(type);

  RouteDefinition get(Type type) => definitions[type]!;
}

class GuardException implements Exception {
  final AppRoute guardRoute;
  GuardException(this.guardRoute);
}

typedef RedirectParser = String Function(List<String> data);
typedef RouteParser = AppRoute Function(List<String> data);

class RouteDefinition<T extends AppRoute> {
  final PageBuilder<T>? onPage;
  final ViewBuilder<T>? onView;
  final GuardFunction<T>? onGuard;
  final PopFunction<T>? onPop;
  RouteDefinition({
    this.onPage,
    this.onView,
    this.onGuard,
    this.onPop
  });
  Page build(AppRouterState state, T route, {bool cupertino = false}) {
    if(onPage != null) {
      final page = onPage!(state, route);
      if(page is AppPage) {
        return _createPage('$route', page._key, page._child);
      } else {
        return page;
      }
    }
    if(onView != null) {
      return _createPage('$route', '$route', onView!(state, route));
    }
    throw 'tried to build page when neither onPage nor onView were set for route: $route';
  }
  AppRoute? guard(AppRouterState state, AppRoute route) => onGuard?.call(state, route as T);
  void pop(AppRouterState state, AppRoute route) => onPop?.call(state, route as T);
  Page _createPage(String name, String key, Widget child, {bool cupertino=false}) {
    if(cupertino) {
      return CupertinoPage(name: name, key: ValueKey(key), child: child);
    } else {
      return MaterialPage(name: name, key: ValueKey(key), child: child);
    }
  }
}

class AppPage extends Page {
  final String _key;
  final Widget _child;
  const AppPage(this._key, this._child);
  @override Route createRoute(BuildContext context) => throw UnimplementedError();
}

abstract class AppRoute {
  const AppRoute();
  int toOrdinal();
  List<AppRoute> toStack() => [this];
}

class HomeRoute extends AppRoute {
  const HomeRoute();
  @override bool operator ==(Object? other) => identical(this, other) || (runtimeType == other?.runtimeType);
  @override int get hashCode => runtimeType.hashCode;
  @override int toOrdinal() => throw 'ordinal not implemented on system routes';
  @override String toString() => '/';
}
class NotFoundRoute extends AppRoute {
  final String _location;
  const NotFoundRoute(this._location);
  @override int toOrdinal() => throw 'ordinal not implemented on system routes';
  @override String toString() => '?$_location';
}
class ErrorRoute extends AppRoute {
  final String _location;
  final String message;
  const ErrorRoute(this._location, this.message);
  @override int toOrdinal() => throw 'ordinal not implemented on system routes';
  @override String toString() => _location;
}
class UninitializedRoute extends ErrorRoute {
  const UninitializedRoute() : super ('!', 'router state not yet initialized');
  @override bool operator ==(Object? other) => identical(this, other) || (runtimeType == other?.runtimeType);
  @override int get hashCode => runtimeType.hashCode;
}


class AppRouterState extends ChangeNotifier {

  final String name;
  final AppRoutes _routes;
  final AppRouterState? parent;
  final children = <AppRouterState>[];
  AppRouterState(this.name, this._routes, {this.parent}) {
    if(parent != null) {
      parent!.children.add(this);
      if(root._current != null) {
        _setNewRoutePath(root._current!);
      }
    }
  }

  int get depth => (parent?.depth ?? -1) + 1;
  AppRouterState get root => parent?.root ?? this;

  AppRoute? _current;
  AppRoute get current => root._current ?? const UninitializedRoute();

  void setNewRoutePath(AppRoute value) {
    if(this == root) {
      if(value is HomeRoute) {
        value = _routes._homeRedirect?.call(this) ?? value;
      }
      if(_current != value) {
        _current = value;
        _setNewRoutePath(value);
      }
    } else {
      root.setNewRoutePath(value);
    }
  }

  void _notify() {
    // final value = findCurrent();
    // if(root._current != value) {
    //   root._current = value;
      if(this != root) {
        root.notifyListeners();
      }
    // }
    notifyListeners();
  }

  List<AppRoute> _stack = [];

  AppRoute get last => _stack.isNotEmpty ? _stack.last : (const UninitializedRoute());

  List<AppRoute> get stack {
    return _stack.map((r) => (r.runtimeType == _routes._homeType) ? r : r.toStack()[depth]).toList();
  }

  int get length => _stack.length;

  void pop() {
    if(_stack.isNotEmpty) {
      _stack.removeLast();
      _notify();
    }
  }

  void add(AppRoute value) {
    final checked = _resolved(value);
    if(checked != null) {
      _stack.add(value);
      _notify();
    }
  }

  void put(AppRoute value) {
    final checked = _resolved(value);
    if(checked != null) {
      if(_stack.isEmpty) {
        _stack = [value];
        _notify();
      }
      else if(_stack.last != checked) {
        _stack.last = value;
        _notify();
      }
    }
  }

  void set(AppRoute value) {
    final checked = _resolved(value);
    if(checked != null && (_stack.length != 1 || _stack[0] != checked)) {
      _stack = [checked];
      _notify();
    }
  }

  AppRoute? _resolved(AppRoute value) {
    if(value.runtimeType == _routes._homeType) return value;
    final stack = value.toStack();
    if(depth < stack.length) {
      final route = stack[depth];
      if(_routes.definitions.isSet(route.runtimeType)) return route;
    }
    return null;
  }

  void _setNewRoutePath(AppRoute value) {
    final checked = _resolved(value);
    if(checked != null && (_stack.length != 1 || _stack[0] != checked)) {
      _stack = [checked];
    }
    notifyListeners();
    for(final child in children) {
      child._setNewRoutePath(value);
    }
  }

  @override
  String toString() => '$runtimeType($name)';
}

class PagesBuilder {
  final AppRoutes routes;
  final AppRouterState state;

  PagesBuilder(this.routes, this.state);

  List<Page> getPages({bool cupertino=false}) {
    final pages = <Page>[];
    try {
      print('${state.name}: stack${state._stack} -> pages${state.stack}');
      for(final route in state.stack) {
        pages.add(getPage(route, guard: true, cupertino: cupertino));
      }
    } on GuardException catch(e) {
      pages.add(getPage(e.guardRoute, cupertino: cupertino));
    } catch(e, st) {
      print('error: $e\n$st');
      pages.add(getPage(ErrorRoute('${state.last}', '$e')));
    }
    return pages;
  }

  Page getPage(AppRoute route, {bool guard=false, bool cupertino=false}) {
    final routeDef = routes.definitionOf(route);
    if(guard) {
      final guardRoute = routeDef.guard(state, route);
      if(guardRoute != null) {
        throw GuardException(guardRoute);
      }
    }
    return routeDef.build(state, route, cupertino: cupertino);
  }
}

class AppRouteParser extends RouteInformationParser<AppRoute> {

  final AppRoutes routes;
  AppRouteParser(this.routes);

  @override
  Future<AppRoute> parseRouteInformation(RouteInformation routeInformation) {
    final location = routeInformation.location ?? '/';
    final route = parseLocation(location);
    return Future.sync(() => route ?? NotFoundRoute(location));
  }

  AppRoute? parseLocation(String location) {
    if(location == '/') {
      return const HomeRoute();
    }
    final segments = location.split('/');
    for(final e in routes.parsers.entries) {
      final parts = e.key.split('/');
      if(matches(parts, segments)) {
        final data = parseData(parts, segments);
        final parser = e.value;
        if(parser is RedirectParser) {
          return parseLocation(parser(data));
        }
        if(parser is RouteParser) {
          return parser(data);
        }
      }
    }
    return null;
  }

  bool matches(List<String> parts, List<String> segments) {
    if(parts.length != segments.length) {
      return false;
    }
    for(var i = 0; i < parts.length && i < segments.length; i++) {
      if(parts[i] != '<>' && parts[i] != segments[i]) {
        return false;
      }
    }
    return true;
  }

  List<String> parseData(List<String> parts, List<String> segments) {
    final data = <String>[];
    for(var i = 0; i < parts.length && i < segments.length; i++) {
      if(parts[i] == '<>') {
        data.add(segments[i]);
      }
    }
    return data;
  }

  @override
  RouteInformation restoreRouteInformation(AppRoute route) {
    return RouteInformation(location: route.toString());
  }
}

class AppRouterDelegate extends RouterDelegate<AppRoute> with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRoute> {

  final bool primary;
  final AppRoutes routes;
  final AppRouterState state;
  final PagesBuilder builder;
  @override final GlobalKey<NavigatorState> navigatorKey;

  bool? _cupertino;
  Type get homeType => routes._homeType;

  AppRouterDelegate(this.routes, this.state, {this.primary=false}) :
    builder = PagesBuilder(routes, state),
    navigatorKey = GlobalKey<NavigatorState>()
  { state.addListener(notifyListeners); }

  @override
  void dispose() {
    state.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  AppRoute? get currentConfiguration => primary ? state.current : null;

  @override
  Future<void> setNewRoutePath(AppRoute route) {
    if(primary) {
      state.setNewRoutePath(route);
    }
    return Future.sync(() => null);
  }

  @override
  Widget build(BuildContext context) {
    _cupertino ??= context.findAncestorWidgetOfExactType<CupertinoApp>() != null;
    return Navigator(
      key: navigatorKey,
      pages: builder.getPages(cupertino: _cupertino!),
      onPopPage: (route, result) {
        if(!route.didPop(result)) {
          return false;
        }
        return popPage(context);
      },
      reportsRouteUpdateToEngine: primary,
    );
  }

  bool popPage(BuildContext context) {
    if(state.length == 1) {
      return false;
    }
    state.pop();
    return true;
  }

  @override
  String toString() => '$runtimeType(name: ${state.name}, route: ${state.last})';
}

class ChildRouter extends StatefulWidget {
  final String name;
  final AppRouterDelegate Function() createRouterDelegate;
  ChildRouter(this.name, this.createRouterDelegate) : super(key: ValueKey('ChildRouter.at($name)'));
  @override
  State<StatefulWidget> createState() => _ChildRouterState();
}
class _ChildRouterState extends State<ChildRouter> {

  late AppRouterDelegate delegate;
  BackButtonDispatcher? dispatcher;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    delegate = widget.createRouterDelegate();
    if(dispatcher != null) {
      _givePriority(context, dispatcher);
    }
    dispatcher = Router.of(context).backButtonDispatcher?.createChildBackButtonDispatcher();
  }

  @override
  void dispose() {
    _givePriority(context, dispatcher);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = Router.of(context);
    final route = (router.routerDelegate as AppRouterDelegate).state.last;
    if(route.runtimeType == delegate.homeType) {
      _takePriority(dispatcher);
    } else {
      _givePriority(context, dispatcher);
    }
    return Router(
      routerDelegate: delegate,
      backButtonDispatcher: dispatcher,
    );
  }

  static BackButtonDispatcher? _priorityDispatcher;

  static void _takePriority(BackButtonDispatcher? dispatcher) {
    _priorityDispatcher = dispatcher?..takePriority();
  }

  static void _givePriority(BuildContext context, BackButtonDispatcher? dispatcher) {
    if(_priorityDispatcher == dispatcher && dispatcher != null) {
      _priorityDispatcher = null;
      Router.of(context).backButtonDispatcher?.takePriority();
    }
  }
}
