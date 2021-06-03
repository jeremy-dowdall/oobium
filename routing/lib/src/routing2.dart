import 'package:collection/collection.dart';
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
typedef GuardFunction<T extends AppRoute> = AppRoute? Function(RouteState<T> state);
typedef PopFunction<T extends AppRoute> = void Function(RouteState<T> state);
typedef PageBuilder<T extends AppRoute> = Page Function(RouteState<T> state);
typedef ViewBuilder<T extends AppRoute> = Widget Function(RouteState<T> state);

// TODO this is mostly a builder... need to separate logical components
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
    required GuardFunction onGuard,
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
  final AppRoute? Function(RouteState state) onGuard;
  GuardedRoutes(this.routes, this.onGuard);

  void page<T extends AppRoute>(String path, PageBuilder<T> onBuild, {
    GuardFunction<T>? onGuard
  }) {
    routes.page<T>(path, onBuild, onGuard: (state) {
      return this.onGuard(state) ?? onGuard?.call(state);
    });
  }

  void view<T extends AppRoute>(String path, ViewBuilder<T> onBuild, {
    GuardFunction<T>? onGuard,
  }) {
    routes.view<T>(path, onBuild, onGuard: (state) {
      return this.onGuard(state) ?? onGuard?.call(state);
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

  Page build(AppRouterState state, AppRoute route, {bool cupertino = false}) {
    final page = onPage?.call(RouteState(state, route as T));
    if(page != null) {
      if(page is AppPage) {
        return _createPage('$route', page._key, page._child);
      } else {
        return page;
      }
    }
    final view = onView?.call(RouteState(state, route as T));
    if(view != null) {
      return _createPage('$route', '$route', view);
    }
    throw 'tried to build page when neither onPage nor onView were set for route: $route';
  }

  AppRoute? guard(AppRouterState state, AppRoute route) {
    return onGuard?.call(RouteState(state, route as T));
  }

  void pop(AppRouterState state, AppRoute route) {
    return onPop?.call(RouteState(state, route as T));
  }

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
  factory HomeRoute() => const HomeRoute._();
  const HomeRoute._();
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
  final String? location;
  final String? message;
  const ErrorRoute({this.location, this.message});
  @override int toOrdinal() => throw 'ordinal not implemented on system routes';
  @override String toString() => '${(location!=null)?'error @ $location\n':''}${message??''}';
}
class UninitializedRoute extends ErrorRoute {
  factory UninitializedRoute() => const UninitializedRoute._();
  const UninitializedRoute._() : super (message: 'router state not yet initialized');
}

class RouteState<T extends AppRoute> {
  final AppRouterState _state;
  final T _route;
  RouteState(this._state, this._route);
  E get<E>() => _state._watch.firstWhere((w) => w is E) as E;
  T get route => _route;
}

/// TODO this is the router engine... don't want push/pop/etc exposed to onPage/onView...
///      state passed to route handlers should be an immutable data class
///      extendable? composable?
///      AppRouterState combines the state, the engine and the notifier
class AppRouterState extends ChangeNotifier {

  final String name;
  final AppRoutes _routes;
  final List<Listenable> _watch;
  final AppRouterState? parent;
  final _children = <AppRouterState>[];
  AppRouterState(this.name, this._routes, this._watch, {this.parent}) {
    if(parent != null) {
      parent!._children.add(this);
      _setNewRoutePath(_root._current);
    }
    _watch.forEach((w) => w.addListener(notifyListeners));
  }

  @override
  void dispose() {
    _watch.forEach((w) => w.removeListener(notifyListeners));
    super.dispose();
  }

  int get _depth => (parent?._depth ?? -1) + 1;
  AppRouterState get _root => parent?._root ?? this;

  AppRoute _current = UninitializedRoute();
  AppRoute get currentGlobal => _root._current;

  void setNewRoutePath(AppRoute value) {
    if(this == _root) {
      if(value is HomeRoute) {
        value = _routes._homeRedirect?.call(this) ?? value;
      }
      if(_current != value) {
        _current = value;
        _setNewRoutePath(value);
      }
    } else {
      _root.setNewRoutePath(value);
    }
  }

  AppRouterState? _activeChild;
  bool get isActive => parent == null || parent?._activeChild == this;
  void activate() {
    if(currentLocal is UninitializedRoute) {
      _setNewRoutePath(_root._current);
    }
    // TODO listeners?
  }
  void deactivate() {
    // TODO listeners?
  }
  void _changed() {
    _activeChild?.deactivate();
    _activeChild = _children.firstWhereOrNull((c) => c._routes._homeType == currentLocal.runtimeType);
    _root._current = _root._findCurrent();
    _activeChild?.activate();
    if(this != _root) {
      _root.notifyListeners();
    }
    notifyListeners();
  }
  AppRoute _findCurrent() {
    return _activeChild?._findCurrent() ?? (_last ?? parent?._last ?? UninitializedRoute());
  }

  List<AppRoute> _stack = [];

  AppRoute? get _last => _stack.isNotEmpty ? _stack.last : null;
  AppRoute get currentLocal => _last ?? UninitializedRoute();

  List<AppRoute> get stack {
    return _stack.map((r) => (r.runtimeType == _routes._homeType) ? r : r.toStack()[_depth]).toList();
  }

  int get length => _stack.length;

  void pop() {
    if(_stack.isNotEmpty) {
      _stack.removeLast();
      _activeChild?._clear();
      _changed();
    }
  }
  void _clear() {
    _stack = [];
    for(final child in _children) {
      if(child == _activeChild) {
        _activeChild?.deactivate();
        _activeChild = null;
      }
      child._clear();
    }
  }

  void add(AppRoute value) {
    final resolved = _resolved(value);
    if(resolved != null && resolved != currentLocal) {
      int i = _stack.indexOf(resolved);
      if(i != -1) {
        _stack.removeRange(i, _stack.length);
      }
      _stack.add(value);
      _changed();
    }
  }

  void put(AppRoute value) {
    final resolved = _resolved(value);
    if(resolved != null) {
      if(_stack.isEmpty) {
        _stack = [value];
        _changed();
      }
      else if(_stack.last != resolved) {
        int i = _stack.indexOf(resolved);
        if(i != -1) {
          _stack.removeRange(i, _stack.length);
          _stack.add(value);
        } else {
          _stack.last = value;
        }
        _changed();
      }
    }
  }

  void set(AppRoute value) {
    final resolved = _resolved(value);
    if(resolved != null && (_stack.length != 1 || _stack[0] != resolved)) {
      _stack = [resolved];
      _changed();
    }
  }

  AppRoute? _resolved(AppRoute value) {
    if(value is UninitializedRoute) return null;
    if(value.runtimeType == _routes._homeType) return value;
    final stack = value.toStack();
    if(_depth < stack.length) {
      final route = stack[_depth];
      if(_routes.definitions.isSet(route.runtimeType)) return route;
    }
    return null;
  }

  void _setNewRoutePath(AppRoute value) {
    final resolved = _resolved(value);
    if(resolved != _last) {
      if(resolved == null) {
        _stack = [];
      } else {
        _stack = [resolved];
      }
      notifyListeners();
    }
    for(final child in _children) {
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
    final keys = <LocalKey?, AppRoute>{};
    final pages = <Page>[];
    final stack = state.stack;
    try {
      print('${state.name}: stack${state._stack} -> pages$stack');
      for(final route in state.stack) {
        final page = getPage(route, guard: true, cupertino: cupertino);
        if(keys.containsKey(page.key)) {
          throw DuplicateKeyException(
            'duplicate page.key, ${page.key}, found in stack ${state.stack}\n'
            '  router: ${state.name}\n'
            '  1st occurance: ${keys[page.key]}\n'
            '  2nd occurance: $route'
          );
        }
        keys[page.key] = route;
        pages.add(page);
      }
    } on GuardException catch(e) {
      pages.add(getPage(e.guardRoute, cupertino: cupertino));

    //  TODO get rid of ErrorRoute... ?
    // } catch(e, st) {
    //   print('error: $e\n$st');
    //   pages.add(getPage(ErrorRoute(location: '${state.currentLocal}', message: '$e')));

    }

    /// TODO: how to handle duplicate keys? (will crash the navigator)
    ///   1. let it crash, cause we shouldn't be adding routes in a way that causes this
    ///   2. let it crash, but print a decent message so the developer knows what went wrong
    ///   3. crash here, with a better message so the developer knows what went wrong
    ///   4. only show the latest page, so it doesn't crash but the routes remain in the back-stack
    ///       was this is the intent?
    ///       or did the developer just forget to use 'set' instead of 'add'? in which case, crashing would be better

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

class DuplicateKeyException implements Exception {
  final String message;
  DuplicateKeyException(this.message);
  @override String toString() => '$runtimeType: $message';
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
      return HomeRoute();
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
  AppRoute? get currentConfiguration => primary ? state.currentGlobal : null;

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
    final pages = builder.getPages(cupertino: _cupertino!);
    return pages.isNotEmpty
      ? Navigator(
          key: navigatorKey,
          pages: pages,
          onPopPage: (route, result) {
            if(!route.didPop(result)) {
              return false;
            }
            return popPage(context);
          },
          reportsRouteUpdateToEngine: primary,
        )
      : Container();
  }

  bool popPage(BuildContext context) {
    if(state.length == 1) {
      return false;
    }
    state.pop();
    return true;
  }

  @override
  String toString() => '$runtimeType(name: ${state.name}, route: ${state.currentLocal})';
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
  late Router router;
  BackButtonDispatcher? dispatcher;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    delegate = widget.createRouterDelegate();
    if(dispatcher != null) {
      _givePriority(router, dispatcher);
    }
    router = Router.of(context);
    dispatcher = router.backButtonDispatcher?.createChildBackButtonDispatcher();
  }

  @override
  void dispose() {
    _givePriority(router, dispatcher);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = (router.routerDelegate as AppRouterDelegate).state.currentLocal;
    if(route.runtimeType == delegate.homeType) {
      _takePriority(dispatcher);
    } else {
      _givePriority(router, dispatcher);
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

  static void _givePriority(Router router, BackButtonDispatcher? dispatcher) {
    if(_priorityDispatcher == dispatcher && dispatcher != null) {
      _priorityDispatcher = null;
      router.backButtonDispatcher?.takePriority();
    }
  }
}
