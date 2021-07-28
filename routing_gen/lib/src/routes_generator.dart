import 'package:collection/collection.dart';

class RoutesGenerator {
  late final String routesLibrary;
  late final String providerLibrary;
  RoutesGenerator(this.routesLibrary, this.providerLibrary);
  factory RoutesGenerator.generate(String name, RoutesClass primary) {
    final sections = primary.sections;
    final routesLibrary =
      'part of \'$name\';'
      '${sections.map((section) => section.compile()).join()}'
    ;
    final providerLibrary =
      'import \'package:flutter/widgets.dart\';'
      'import \'$name\';'
      'extension BuildContextX on BuildContext {'
        '${sections.map((s) => '${s.name} get ${s.varName} => RoutesProvider.of(this).${s.varName};').join()}'
      '}'
      'typedef Builder = Widget Function(BuildContext context, Routes mainRoutes);'
      'class RoutesProvider extends InheritedWidget {'
        '${sections.map((s) => 'late final ${s.name} ${s.varName};').join()}'
        'RoutesProvider({required Builder builder}) : super(child: _RoutesProviderChild(builder)) {'
          '${sections.map((s) => '${s.varName} = ${s.builder}(${s.builderVar});').join()}'
        '}'
        '@override bool updateShouldNotify(covariant InheritedWidget oldWidget) => true;'
        'static RoutesProvider of(BuildContext context) {'
          'return context.findAncestorWidgetOfExactType<RoutesProvider>() ?? (throw \'RoutesProvider not found in widget hierarchy\');'
        '}'
      '}'
      'class _RoutesProviderChild extends StatelessWidget {'
        'final Builder builder;'
        '_RoutesProviderChild(this.builder);'
        '@override Widget build(BuildContext context) {'
          'return builder(context, context.${primary.varName});'
        '}'
      '}'
    ;
    return RoutesGenerator(routesLibrary, providerLibrary);
  }
}

class RoutesParser {
  final Iterable<String> lines;
  RoutesParser(this.lines);

  RoutesClass? parse() {
    final routes = findRoutesClass();
    if(routes != null) {
      findChildRoutesClasses(routes);
    }
    return routes;
  }

  RoutesClass? findRoutesClass() {
    for(var iter = lines.iterator; iter.moveNext(); ) {
      final line = iter.current;
      final routes = RegExp(r'final\s+([\w_]+)\s+=\s+_Routes\(').firstMatch(line);
      if(routes != null) {
        final section = RoutesClass(
          sections: <RoutesClass>[],
          name: 'Routes',
          builder: routes.group(1)!
        );
        while(iter.moveNext() && section.parseLine(iter.current));
        section.sections.add(section);
        return section;
      }
    }
    return null;
  }

  void findChildRoutesClasses(RoutesClass parent) {
    for(final route in parent.routes) {
      final childRoutes = findChildRoutesClass(parent, route);
      if(childRoutes != null) {
        findChildRoutesClasses(childRoutes);
      }
    }
  }

  RoutesClass? findChildRoutesClass(RoutesClass parent, RouteClass route) {
    for(var iter = lines.iterator; iter.moveNext(); ) {
      final line = iter.current;
      final childRoutes = RegExp('final\\s+([\\w_]+)\\s+=\\s+${parent.builder}\\.at$route\\(').firstMatch(line);
      if(childRoutes != null) {
        route.child = true;
        final section = RoutesClass(
          parent: parent,
          sections: parent.sections,
          name: 'RoutesAt${route.name}',
          builder: childRoutes.group(1)!,
          homeRoute: route,
        );
        while(iter.moveNext() && section.parseLine(iter.current));
        parent.sections.add(section);
        return section;
      }
    }

    return null;
  }
}

class RoutesClass {

  final RoutesClass? parent;
  final List<RoutesClass> sections;
  final String name;
  final String builder;
  final RouteClass? homeRoute;
  final items = <Object>[];
  RoutesClass({
    this.parent,
    required this.sections,
    required this.name,
    required this.builder,
    this.homeRoute,
  });

  Iterable<ParserClass> get allParsers => sections.fold<List<ParserClass>>([], (a,s) {a.addAll(s.items.whereType<ParserClass>()); return a;});
  Iterable<RouteClass> get allRoutes => sections.fold<List<RouteClass>>([], (a,s) {a.addAll(s.items.whereType<RouteClass>()); return a;});
  Iterable<RouteClass> get routes => items.whereType<RouteClass>();

  bool get isPrimary => homeRoute == null;
  bool get isNotPrimary => !isPrimary;

  String get shortBuilder => builder.endsWith('Builder')
    ? builder.substring(0, builder.length-'Builder'.length)
    : builder;
  String get varName => '${shortBuilder}Routes';
  String get builderVar => parent?.varName ?? '';

  bool parseLine(String line) {
    if(line == ');') {
      return false;
    }
    final eol = line.indexOf(';');
    final str = (eol != -1) ? line.substring(0, eol) : line;
    final route = RegExp(r"\s*\.?\.?[page|view]<([\w_]+)>\(\s*'([^']*)'").firstMatch(str);
    if(route != null) {
      final routeClass = route.group(1);
      final routePath = route.group(2);
      if(routeClass != null && routePath != null) {
        items.add(RouteClass(
            this,
            routeClass,
            routePath,
            RegExp(varPattern).allMatches(routePath).map((matches) {
              return _Field(matches.group(1)!, matches.group(3) ?? 'String');
            }),
            homeRoute
        ));
      }
    } else {
      final redirect = RegExp(r"\s*\.?\.?redirect\(\s*'([^']*)'\s*,\s*'([^']*)'\s*\)").firstMatch(str);
      if(redirect != null) {
        items.add(RedirectClass(
          this,
          redirect.group(1)!,
          redirect.group(2)!,
        ));
      }
    }
    return true;
  }

  String compile() {
    if(isPrimary) {
      return
        'class _$name {'
          'final Build<HomeRoute> _build;'
          'final Watch? _watch;'
          '_$name(this._build, {Watch? watch}) : _watch = watch;'
          '$name call({List<RouteDefinition>? route, List? watch}) => $name('
            '_build,'
            '[...?route],'
            '[...?_watch?.call(), ...?watch]'
          ');'
          '${compileAtRoutes()}'
        '}'
        'class $name {'
          'final AppRoutes<HomeRoute> _routes;'
          'late final AppRouterState _state;'
          '$name(Build<HomeRoute> build, List route, List watch) :'
            '_routes = AppRoutes<HomeRoute>({${compileParsers()}}) {'
              'build(_routes);'
              'for(final def in route) {'
                '_routes.definitions.add(def);'
              '}'
              '_state = AppRouterState(\'$name\', _routes, watch);'
          '}'
          'late final routeParser = AppRouteParser(_routes);'
          'late final routerDelegate = AppRouterDelegate(_routes, _state, primary: true);'
          '${compileOrdinals()}'
          'void setNewRoutePath(AppRoute route) => _state.setNewRoutePath(route);'
          '${compileRouting()}'
        '}'
        '${routes.mapIndexed((i,r) => r.compile(i)).join()}'
      ;
    } else {
      return
        'class _$name {'
          'final Build<$homeRoute> _build;'
          'final List<Listenable> _watch;'
          '_$name(this._build, {List<Listenable>? watch}) : _watch = watch ?? [];'
          '$name call(${parent!.name} parent) => $name(parent._state, _build, _watch);'
          '${compileAtRoutes()}'
        '}'
        'class $name {'
          'final AppRoutes<$homeRoute> _routes;'
          'late final AppRouterState _state;'
          '$name(AppRouterState parent, Build<$homeRoute> build, List<Listenable> watch) :'
            '_routes = AppRoutes<$homeRoute>() {'
              'build(_routes);'
              '_state = AppRouterState(\'$name\', _routes, watch, parent: parent);'
          '}'
          'ChildRouter call() => ChildRouter(\'$name\', () => AppRouterDelegate(_routes, _state));'
          '${compileOrdinals()}'
          '${compileRouting()}'
        '}'
        '${routes.mapIndexed((i,r) => r.compile(i)).join()}'
      ;
    }
  }

  String compileAtRoutes() => routes.map((r) => r.child
    ? '_RoutesAt${r.name} at${r.name}(Build<${r.name}> build) => _RoutesAt${r.name}(build);'
    : 'Object at${r.name}(Build build) => const Object();'
  ).join();

  String compileOrdinals() => routes.every((r) => r.isConstant)
    ? 'AppRoute fromOrdinal(int ordinal) {'
        'switch(ordinal) {'
          '${routes.mapIndexed((i,r) => 'case $i: return ${r.name}();').join()}'
        '}'
        'return ErrorRoute(message: \'invalid ordinal, \$ordinal, requested from $name\');'
      '}'
      'void addFromOrdinal(int ordinal) => _state.add(fromOrdinal(ordinal));'
      'void putFromOrdinal(int ordinal) => _state.put(fromOrdinal(ordinal));'
      'void setFromOrdinal(int ordinal) => _state.set(fromOrdinal(ordinal));'
    : '';

  String compileNewRoute(RouteClass r) =>
    '${r.isConstant?'const ':''}${r.name}(${r.vars.map((v) => '$v: $v').join(',')})';

  String compileParams(RouteClass r) => r.vars.isNotEmpty
    ? '{${r.vars.map((v) => 'required ${v.type} $v').join(',')}}'
    : '';

  String compileParsers() => allParsers.map((r) => r.compileParser()).join(',');

  String compileRouting() =>
    'AppRoute get current => _state.currentLocal;'
    'void pop() => _state.pop();'
    '${routes.map((r) =>
      'void add${r.shortName}(${compileParams(r)}) => _state.add(${compileNewRoute(r)});'
      'void put${r.shortName}(${compileParams(r)}) => _state.put(${compileNewRoute(r)});'
      'void set${r.shortName}(${compileParams(r)}) => _state.set(${compileNewRoute(r)});'
    ).join()}';
}

abstract class ParserClass {
  String compileParser();
}
const varPattern = r'\<([\w_]+)(:(int|bool))?\>';

class RedirectClass implements ParserClass {
  final RoutesClass section;
  final String src;
  final String dst;
  RedirectClass(this.section, this.src, this.dst);

  @override
  String compileParser() {
    final key = compileParserKey();
    final dstFields = RegExp(varPattern).allMatches(dst).map((matches) => matches.group(1)!);
    if(dstFields.isEmpty) {
      return '\'$key\': (_) => $dst';
    } else {
      final srcFields = RegExp(varPattern).allMatches(src).map((matches) => matches.group(1)!).toList();
      final result = dst.split('/').toList().map((s) {
        final index = srcFields.indexOf(s);
        return (index == -1) ? s : '\$\{data[$index]\}';
      }).join('/');
      return '\'$key\': (data) => \'$result\'';
    }
  }

  String compileParserKey() => src.replaceAllMapped(RegExp(varPattern), (match) => '<${match.group(3) ?? ''}>');
}

class Count {
  var i = 0;
  int get inc => i++;
}
class RouteClass implements ParserClass {
  final RoutesClass section;
  final String name;
  final String path;
  final Iterable<_Field> fields;
  final RouteClass? parent;
  RouteClass(this.section, this.name, this.path, this.fields, this.parent);

  bool get isConstant => isEmpty;
  bool get isNotConstant => !isConstant;

  bool get isEmpty => fields.isEmpty;
  bool get isNotEmpty => !isEmpty;

  bool child = false;
  bool get childless => !child;

  String get shortName => name.endsWith('Route')
    ? name.substring(0, name.length-'Route'.length)
    : name;

  String get varName => '${name[0].toLowerCase()}${shortName.substring(1)}';

  _Field asVar() => _Field(varName, name);

  _Field? get parentVar => parent?.asVar();
  List<_Field> get vars {
    final parentVar = this.parentVar;
    final vars = fields.toList();
    if(parentVar != null && parent!.isNotConstant) {
      vars.add(parentVar);
    }
    return vars;
  }

  String compile(int ordinal) {
    final vars = this.vars;
    final parentVar = this.parentVar;
    return [
      'class $name extends AppRoute {',
        if(vars.isEmpty)
          'const $name();'
          '@override bool operator ==(Object? other) => identical(this, other) || (other is $name);'
          '@override int get hashCode => runtimeType.hashCode;',
        for(final v in vars)
          'final ${v.type} $v;',
        if(parentVar != null && parent!.isConstant)
          'final $parentVar = const ${parentVar.type}();',
        if(vars.isNotEmpty)
          'const $name({${vars.map((v) => 'required this.$v').join(',')}});'
          '@override bool operator ==(Object? other) => identical(this, other) || (other is $name && ${vars.map((v) => '$v == other.$v').join('&&')});'
          '@override int get hashCode => hashValues(runtimeType, ${vars.join(',')});',
        '@override int toOrdinal() => $ordinal;',
        if(parentVar == null)
          '@override String toString() => \'${path.replaceAllMapped(RegExp(varPattern), (m) => '\$${m.group(1)}')}\';'
        else
          '@override List<AppRoute> toStack() => [...$parentVar.toStack(), this];'
          '@override String toString() => \'\$$parentVar${path.replaceAllMapped(RegExp(varPattern), (m) => '\$${m.group(1)}')}\';',
      '}'
    ].join();
  }

  @override
  String compileParser() {
    final key = compileParserKey();
    if(fields.isEmpty) {
      return '\'$key\': (_) => const $name()';
    } else {
      return '\'$key\': (data) => ${compileParserValue(Count())}';
    }
  }

  String compileParserKey() {
    final lookup = path.replaceAllMapped(RegExp(varPattern), (match) => '<${match.group(3) ?? ''}>');
    return (parent != null) ? '${parent!.compileParserKey()}$lookup' : lookup;
  }

  String compileParserValue(Count c) {
    if(parent != null && parent!.isNotConstant) {
      final px = parent?.compileParserValue(c);
      return '$name(${fields.map((f) => '$f: data[${c.inc}],').join()}${parent!.asVar()}: $px)';
    } else {
      return '$name(${fields.map((f) => '$f: data[${c.inc}],').join()})';
    }
  }

  @override
  String toString() => name;
}

class _Field {
  final String name;
  final String type;
  _Field(this.name, [this.type='String']);
  @override String toString() => name;
}
