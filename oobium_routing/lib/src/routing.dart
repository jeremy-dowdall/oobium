import 'package:flutter/widgets.dart';
import 'package:collection/collection.dart';

extension BuildContextOobiumRoutingExtentions on BuildContext {

  Router get router => Router.of(this);
  AppRoutes get routes => (router.routerDelegate as AppRouterDelegate).routes;
  AppRoute? get route => routes.state.route;
  set route(AppRoute? value) => routes.state.route = value;
  set newRoutePath(AppRoute value) => router.routerDelegate.setNewRoutePath(value);

}

abstract class AppRoute {

  bool _isHome = false;
  bool get _isNotHome => !_isHome;

  AppRoute? _parent;
  AppRoute? get parent => _parent;
  set parent(AppRoute? value) {
    assert(value != this);
    _parent = value;
  }

  final Map<String, String> _data;
  AppRoute([Map<String, String>? data]) : _data = data ?? {};

  String operator [](String key) => _data[key] ?? '';

  @override
  String toString() => '$runtimeType($_data)';

  @override
  bool operator ==(Object? other) {
    if(identical(this, other)) return true;
    return other?.runtimeType == runtimeType && (other is AppRoute)
        && other._data.length == _data.length
        && other._data.keys.every((k) => other._data[k] == _data[k]);
  }

  @override
  int get hashCode => hashValues(runtimeType, _data);

}

class AppRoutes<E extends AppRouterState> {

  final E state;
  String? _homePath;
  AppRoutes({E? state, String? home}) :
    state = state ?? ((E == AppRouterState) ? (AppRouterState() as E) : throw Exception('custom state type, $E, must be passed in to AppRoutes'))
  {
    this._root = this;
    this.state._routes = this;
    if(home != null) _homePath = home;
  }

  final Map<Type, _RouteDef> definitions = {};

  AppRoute? _currentConfiguration;
  AppRoute? get currentConfiguration => _currentConfiguration;
  set currentConfiguration(AppRoute? value) => _setCurrentConfiguration(value, true);

  late AppRoutes _root;
  AppRoutes? _parent;
  bool _updatingConfig = false;
  void _setCurrentConfiguration(AppRoute? value, bool reset) {
    if(!_updatingConfig) {
      _updatingConfig = true;
      try {
        _doSetCurrentConfiguration(value, reset);
      } finally {
        _updatingConfig = false;
      }
    }
  }
  void _doSetCurrentConfiguration(AppRoute? value, bool reset) {
    if(!reset && value != null) {
      for(AppRoute? r = value; r != null && r._isNotHome; r = getAppRoutes(r).definitions[r.runtimeType]?.children?.state.route) value = r;
    }
    if(_currentConfiguration == value) {
      return;
    }
    final oldList = <AppRoute>[];
    final newList = <AppRoute>[];
    if(reset && _currentConfiguration != null) {
      for(var r = _currentConfiguration; r != null; r = r.parent) oldList.add(r);
    }

    _currentConfiguration = value;

    if(_currentConfiguration != null) {
      for(var r = _currentConfiguration; r != null; r = r.parent) newList.add(r);
    }
    for(var r in oldList.where((r) => !newList.contains(r))) getAppRoutes(r).state.reset();
    for(var r in newList.reversed) getAppRoutes(r).state.route = r;
    if(value?.parent != null) {
      state._notifyListeners();
    }
  }

  add<T extends AppRoute>({
    required String path,
    required T onParse(Map<String, String> data),
    required List<Page> onBuild(T route),
    AppRoute Function(E state)? onGuard,
    void Function(E state)? onPop,
    AppRoutes? children
  }) {
    assert(!definitions.containsKey(T), 'duplicate route: $T');

    _homePath ??= path;

    final shadowPath = _getPaths(path).join();
    assert(shadowPath.isEmpty, 'duplicate path: $path${(path != shadowPath) ? ' shadows $shadowPath' : ''}');

    definitions[T] = _RouteDef<E, T>(path: path, onParse: onParse, onBuild: onBuild, onGuard: onGuard, onPop: onPop, children: children);

    if(path == _homePath) {
      state._route = homeRoute;
    }
    if(children != null) {
      children._root = _root;
      children._parent = this;
      children.state._route = children.homeRoute;
    }
  }

  AppRoutes? of<T extends AppRoute>() => definitions[T]?.children;

  AppRouteParser createRouteParser() => AppRouteParser(this);
  AppRouterDelegate createRouterDelegate() => AppRouterDelegate(this);

  AppRoute get homeRoute {
    final route = _getDefinition(_homePath)?.parse({});
    assert(route != null, 'home is not set correctly (home == \'$_homePath\', but no route is defined at that location)');
    route!._parent = _parent?.state.route;
    route._isHome = true;
    return route;
  }
  
  AppRoute get notFoundRoute {
    throw 'not yet implemented';
  }

  AppRoute? getParentRoute(AppRoute route) {
    final path = definitions[route.runtimeType]?.path;
    final sa = path?.split('/');
    if(sa != null && sa.length > 1) {
      final newPath = sa.sublist(0, sa.length - 1).join('/');
      return _getDefinition(newPath)?.parse(route._data);
    }
    return null;
  }

  List<Page> getPages() {
    assert(state.route != null, 'tried to build pages before setting a route');
    return getPagesFor(state.route);
  }
  List<Page> getPagesFor(AppRoute? route) {
    if(route == null) {
      return [];
    } else {
      final routeDef = definitions[route.runtimeType]!;
      return [...routeDef.build(route), ...getPagesFor(routeDef.guard(state))];
    }
  }

  bool popPage() {
    final route = state.route;
    if(route != null) {
      final routeDef = definitions[route.runtimeType]!;
      if(routeDef.canPop) {
        routeDef.pop(state);
      } else {
        state.route = getParentRoute(route) ?? homeRoute;
      }
    }
    return true;
  }

  Future<AppRoute> parseRouteInformation(RouteInformation routeInformation) async {
    final uri = Uri.tryParse(routeInformation.location ?? '')?.path ?? '';
    final paths = _getPaths(uri, home: _homePath);
    if(paths.isEmpty) {
      print('route not found: $uri');
      return notFoundRoute;
    }
    final data = _getData(paths.join(), uri);
    if(paths.length == 1) {
      return _getDefinition(paths[0])!.parse(data);
    } else {
      var route;
      for(var i = 0; i < paths.length; i++) {
        route = _findDefinition(this, paths.sublist(0, i + 1)).parse(data)..parent = route;
      }
      return route;
    }
  }

  RouteInformation restoreRouteInformation(AppRoute route) {
    AppRoute? r = route;
    final locations = <String>[];
    while(r != null) {
      locations.add(getLocation(r));
      r = r.parent;
    }
    return RouteInformation(location: locations.reversed.join());
  }

  AppRoutes getAppRoutes(AppRoute route) {
    final routeList = <AppRoute>[];
    for(var r = route.parent; r != null; r = r.parent) routeList.insert(0, r);
    return routeList.fold<AppRoutes>(this, (routes, route) => routes.definitions[route.runtimeType]!.children!);
  }

  String getLocation(AppRoute route) {
    final routes = getAppRoutes(route);
    return routes.definitions[route.runtimeType]!.path.replaceAllMapped(RegExp(r'<(\w+)>'), (m) => route[m[1]!]);
  }

  _RouteDef? _getDefinition(String? path) => definitions.values.firstWhereOrNull((d) => d.path == path);

  _RouteDef _findDefinition(AppRoutes routes, List<String> paths, [index = 0]) {
    final def = routes._getDefinition(paths[index])!;
    return (index == paths.length - 1) ? def : _findDefinition(def.children!, paths, index + 1);
  }

  List<String> _getPaths(String path, {String? home}) {
    if(path.isNotEmpty) {
      final s = ((path != '/') ? path : home) ?? path;
      final sa = _segments(s);
      for(var def in definitions.values) {
        final k = def.path;
        final ka = _segments(k);
        if(_matches(sa, ka)) {
          if(ka.length == sa.length) { // full match
            return [k];
          } else { // partial match (check children for completions)
            final c = def.children;
            if(c != null) {
              final p = c._getPaths(sa.sublist(ka.length).join('/'));
              if(p.isNotEmpty) {
                return [k, ...p];
              }
            }
          }
        }
      }
    }
    return [];
  }

  Map<String, String> _getData(String path, String location) {
    final data = Map<String, String>();
    final s1 = _segments(path);
    final s2 = _segments(location);
    for(var i = 0; i < s1.length; i++) {
      if(_isVariable(s1[i])) {
        data[s1[i].substring(1, s1[i].length-1)] = s2[i];
      }
    }
    return data;
  }

  List<String> _segments(String s) => s.split('/').where((e) => e.isNotEmpty).toList();

  bool _matches(List<String> s1, List<String> s2) {
    for(var i = 0; i < s1.length && i < s2.length; i++) {
      if(s1[i] != s2[i] && _isNotVariable(s1[i]) && _isNotVariable(s2[i])) {
        return false;
      }
    }
    return true;
  }

  bool _isVariable(String? s) => s != null && s.isNotEmpty && s[0] == '<';
  bool _isNotVariable(String? s) => !_isVariable(s);
}

class AppRouterState extends ChangeNotifier {

  late AppRoutes _routes;

  void reset() {
    route = _routes.homeRoute;
  }

  AppRoute? _route;
  AppRoute? get route => _route;
  set route(AppRoute? value) {
    assert(
      value == null || _routes.definitions[value.runtimeType] != null,
      'unsupported route: $value (this is probably not the delegate you were looking for)'
    );
    if(_route != value) {
      if(value == null) {
        _route = null;
      } else {
        _route = value..parent = _routes._parent?.state.route;
        _routes._root._setCurrentConfiguration(_route, false);
      }
      notifyListeners();
    } else {
      _routes._root._setCurrentConfiguration(_route, false);
    }
  }

  _notifyListeners() => notifyListeners();
}

class AppRouteParser extends RouteInformationParser<AppRoute> {

  final AppRoutes routes;
  AppRouteParser(this.routes);

  @override
  Future<AppRoute> parseRouteInformation(RouteInformation routeInformation) => routes.parseRouteInformation(routeInformation);

  @override
  RouteInformation restoreRouteInformation(AppRoute route) => routes.restoreRouteInformation(route);
}

class AppRouterDelegate extends RouterDelegate<AppRoute> with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRoute> {

  final AppRoutes routes;
  @override final GlobalKey<NavigatorState> navigatorKey;

  AppRouterDelegate(this.routes) : navigatorKey = GlobalKey<NavigatorState>() {
    routes.state.addListener(notifyListeners);
  }

  @override
  void dispose() {
    routes.state.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  AppRoute? get currentConfiguration => routes.currentConfiguration;

  @override
  Future<void> setNewRoutePath(AppRoute route) async => routes.currentConfiguration = route;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: routes.getPages(),
      onPopPage: (route, result) {
        if(!route.didPop(result)) {
          return false;
        }
        return routes.popPage();
      },
      reportsRouteUpdateToEngine: true,
    );
  }
}

class ChildRouter<T extends AppRoute> extends StatefulWidget {

  ChildRouter() :
        assert(T != AppRoute, 'tried creating a ChildRouter without specifying a route type, correct use: ChildRouter<MyRoute>()'),
        super(key: ValueKey(T));

  @override
  State<StatefulWidget> createState() => _ChildRouterState<T>();
}
class _ChildRouterState<T extends AppRoute> extends State<ChildRouter> {

  late AppRouterDelegate delegate;
  BackButtonDispatcher? dispatcher;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routes = context.routes.of<T>();
    assert(routes != null, 'could not get child routes for $T');
    delegate = routes!.createRouterDelegate();
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
    if(context.route.runtimeType == T) {
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

class _RouteDef<E extends AppRouterState, T extends AppRoute> {
  final String path;
  final T Function(Map<String, String> data) onParse;
  final List<Page> Function(T route) onBuild;
  final AppRoute Function(E state)? onGuard;
  final void Function(E state)? onPop;
  final AppRoutes? children;
  _RouteDef({
    required this.path,
    required this.onParse,
    required this.onBuild,
    this.onGuard,
    this.onPop,
    this.children
  });
  bool get canPop => onPop != null;
  List<Page> build(AppRoute route) => onBuild(route as T);
  AppRoute? guard(AppRouterState state) => onGuard?.call(state as E);
  AppRoute parse(Map<String, String> data) => onParse(data);
  void pop(AppRouterState state) => onPop?.call(state as E);
}

