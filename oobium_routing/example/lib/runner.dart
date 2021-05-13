import 'dart:io';

import 'package:collection/collection.dart';

Future<void> main(List<String> args) async {
  final params = _params(args);
  final directory = _directory(params);

  print('scanning ${directory.path} for routes...');
  final files = await directory.list(recursive: true).where((file) => file.path.endsWith('routes.dart')).toList();
  if(files.isEmpty) {
    print('no routes files found');
  }

  for(var file in files) {
    final path = file.path.substring(directory.path.length + 1); // remove leading slash
    final name = file.path.substring(file.parent.path.length + 1).replaceAll('.dart', '');
    print('found $name (${file.path})... processing...');

    final lines = await (file as File).readAsLines();
    final routes = RoutesParser(lines).parse();

    if(routes == null) {
      print('no routes found... exiting');
    } else {
      final library = [
        'part of \'$name.dart\';',
        'typedef Build<T extends AppRoute> = void Function(AppRoutes<T> r);',
        ...routes.sections.map((section) => section.compile())
      ].join('\n');

      final outputs = <File>[];
      outputs.add(await File('${directory.path}/${path.replaceAll('.dart', '.g.dart')}').writeAsString(library));
      print('  $path processed. formatting...');

      final results = await Process.run('dart', ['format', ...outputs.map((f) => f.path).toList()]);
      print(results.stdout);
    }
  }
}

class RoutesParser {
  final List<String> lines;
  RoutesParser(this.lines);

  SectionClass? parse() {
    final routes = findRoutesClass();
    if(routes != null) {
      findChildRoutesClasses(routes);
    }
    return routes;
  }

  SectionClass? findRoutesClass() {
    for(var i = 0; i < lines.length; i++) {
      final line = lines[i];

      final routes = RegExp(r'\s+_Routes\(').firstMatch(line);
      if(routes != null) {
        final home = RegExp(r'[\(,\s]home:\s*[new|const]*\s*([\w_]+)[\(\),]').firstMatch(line);
        final state = RegExp(r'[\(,\s]state:\s*[new]*\s*([\w_]+)[\(,\)]').firstMatch(line);
        final section = SectionClass(
          parent: null,
          sections: <SectionClass>[],
          routesClass: '_Routes',
          homeClass: home?.group(1) ?? 'MissingHome',
          stateClass: state?.group(1) ?? 'AppRouterState',
        );
        while(i < lines.length && section.parseLine(lines[i])) {
          i++;
        }
        section.sections.add(section);
        return section;
      }
    }
    return null;
  }

  void findChildRoutesClasses(SectionClass parent) {
    for(final route in parent.routes) {
      final childRoutes = findChildRoutesClass(parent, route);
      if(childRoutes != null) {
        findChildRoutesClasses(childRoutes);
      }
    }
  }

  SectionClass? findChildRoutesClass(SectionClass parent, RouteClass route) {
    for(var i = 0; i < lines.length; i++) {
      final line = lines[i];

      final childRoutes = RegExp('\\.at${route.name}\\(').firstMatch(line);
      if(childRoutes != null) {
        route.child = true;
        final section = SectionClass(
          parent: parent,
          sections: parent.sections,
          routesClass: '_RoutesAt${route.name}',
          homeClass: route.name,
          stateClass: 'AppRouterState',
          parentClass: route.name,
        );
        while(i < lines.length && section.parseLine(lines[i])) {
          i++;
        }
        parent.sections.add(section);
        return section;
      }
    }

    return null;
  }
}

class SectionClass {

  final SectionClass? parent;
  final List<SectionClass> sections;
  final String routesClass;
  final String homeClass;
  final String stateClass;
  final String? parentClass;
  final items = <Object>[];
  SectionClass({
    required this.parent,
    required this.sections,
    required this.routesClass,
    required this.homeClass,
    required this.stateClass,
    this.parentClass,
  });

  Iterable<ParserClass> get allParsers => sections.fold<List<ParserClass>>([], (a,s) {a.addAll(s.items.whereType<ParserClass>()); return a;});
  Iterable<RouteClass> get allRoutes => sections.fold<List<RouteClass>>([], (a,s) {a.addAll(s.items.whereType<RouteClass>()); return a;});
  Iterable<RouteClass> get routes => items.whereType<RouteClass>();

  bool get isPrimary => parentClass == null;
  bool get isNotPrimary => !isPrimary;

  bool parseLine(String line) {
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
            RegExp(r'\<([\w_]+)\>').allMatches(routePath).map((matches) => _Field(matches.group(1)!)),
            parentClass
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
    return (eol == -1);
  }

  String compile() {
    if(isPrimary) {
      return
        'class $routesClass {'
          'final Build<HomeRoute> _build;'
          '$routesClass(this._build);'
          '$routesClass\$ call() => $routesClass\$(_build);'
          '${compileAtRoutes()}'
        '}'
        'class $routesClass\$ {'
          'final AppRoutes<HomeRoute> _routes;'
          'late final AppRouterState _state;'
          '$routesClass\$(Build<HomeRoute> build) :'
            '_routes = AppRoutes<HomeRoute>({${compileParsers()}}) {'
              'build(_routes);'
              '_state = AppRouterState(\'$routesClass\', _routes);'
          '}'
          'AppRouteParser createRouteParser() => AppRouteParser(_routes);'
          'AppRouterDelegate createRouterDelegate() => AppRouterDelegate(_routes, _state, primary: true);'
          '${compileOrdinals()}'
          'void setNewRoutePath(AppRoute route) => _state.setNewRoutePath(route);'
          '${compileRouting()}'
        '}'
        '${routes.mapIndexed((i,r) => r.compile(i)).join()}'
      ;
    } else {
      return
        'class $routesClass {'
          'final Build<$parentClass> _build;'
          '$routesClass(this._build);'
          '$routesClass\$ call(${parent!.routesClass}\$ parent) => $routesClass\$(parent._state, _build);'
          '${compileAtRoutes()}'
        '}'
        'class $routesClass\$ {'
          'final AppRoutes<$parentClass> _routes;'
          'late final AppRouterState _state;'
          '$routesClass\$(AppRouterState parent, Build<$parentClass> build) :'
            '_routes = AppRoutes<$parentClass>() {'
              'build(_routes);'
              '_state = AppRouterState(\'$routesClass\', _routes, parent: parent);'
          '}'
          'ChildRouter router() => ChildRouter(\'$routesClass\', () => AppRouterDelegate(_routes, _state));'
          '${compileOrdinals()}'
          '${compileRouting()}'
        '}'
        '${routes.mapIndexed((i,r) => r.compile(i)).join()}'
      ;
    }
  }

  String compileAtRoutes() => routes.map((r) => r.child
    ? '_RoutesAt${r.name} at${r.name}(Build<${r.name}> build) => _RoutesAt${r.name}(build);'
    : 'Object at${r.name}(Build build) => Object();'
  ).join();

  String compileOrdinals() => routes.every((r) => r.isConstant)
    ? 'AppRoute fromOrdinal(int ordinal) {'
        'switch(ordinal) {'
          '${routes.mapIndexed((i,r) => 'case $i: return ${r.name}();').join()}'
        '}'
        'throw \'invalid ordinal: \$ordinal\';'
      '}'
      'void addFromOrdinal(int ordinal) => _state.add(fromOrdinal(ordinal));'
      'void putFromOrdinal(int ordinal) => _state.put(fromOrdinal(ordinal));'
      'void setFromOrdinal(int ordinal) => _state.set(fromOrdinal(ordinal));'
    : '';

  String compileNewRoute(RouteClass r) =>
    '${r.name}(${r.vars.map((v) => '$v: $v').join(',')})';

  String compileParams(RouteClass r) => r.vars.isNotEmpty
    ? '{${r.vars.map((v) => 'required ${v.type} $v').join(',')}}'
    : '';

  String compileParsers() => allParsers.map((r) => r.compileParser()).join(',');

  String compileRouting() =>
    'AppRoute get current => _state.last;'
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

class RedirectClass implements ParserClass {
  final SectionClass section;
  final String src;
  final String dst;
  RedirectClass(this.section, this.src, this.dst);

  @override
  String compileParser() {
    final key = compileParserKey();
    final dstFields = RegExp(r'(\<[\w_]+\>)').allMatches(dst).map((matches) => matches.group(1)!);
    if(dstFields.isEmpty) {
      return '\'$key\': (_) => $dst';
    } else {
      final srcFields = RegExp(r'(\<[\w_]+\>)').allMatches(src).map((matches) => matches.group(1)!).toList();
      final result = dst.split('/').toList().map((s) {
        final index = srcFields.indexOf(s);
        return (index == -1) ? s : '\$\{data[$index]\}';
      }).join('/');
      return '\'$key\': (data) => \'$result\'';
    }
  }

  String compileParserKey() => src.replaceAllMapped(RegExp(r'\<([\w_]+)\>'), (match) => '<>');
}

class Count {
  var i = 0;
  int get inc => i++;
}
class RouteClass implements ParserClass {
  final SectionClass section;
  final String name;
  final String path;
  final Iterable<_Field> fields;
  final String? parentName;
  RouteClass(this.section, this.name, this.path, this.fields, this.parentName);

  bool get isConstant => isEmpty;
  bool get isNotConstant => !isConstant;

  bool get isEmpty => fields.isEmpty;
  bool get isNotEmpty => !isEmpty;

  RouteClass? get parent => section.allRoutes.firstWhereOrNull((route) => route.name == parentName);

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
          '@override bool operator ==(Object? other) => identical(this, other) || (runtimeType == other?.runtimeType);'
          '@override int get hashCode => runtimeType.hashCode;',
        for(final v in vars)
          'final ${v.type} $v;',
        if(parentVar != null && parent!.isConstant)
          'final $parentVar = const ${parentVar.type}();',
        if(vars.isNotEmpty)
          'const $name({${vars.map((v) => 'required this.$v').join(',')}});'
          '@override bool operator ==(Object? other) => identical(this, other) || (runtimeType == other?.runtimeType && other is $name && ${vars.map((v) => '$v == other.$v').join('&&')});'
          '@override int get hashCode => hashValues(runtimeType, ${vars.join(',')});',
        '@override int toOrdinal() => $ordinal;',
        if(parentVar == null)
          '@override String toString() => \'${path.replaceAllMapped(RegExp(r'\<([\w_]+)\>'), (m) => '\$${m.group(1)}')}\';'
        else
          '@override List<AppRoute> toStack() => [...$parentVar.toStack(), this];'
          '@override String toString() => \'\$$parentVar${path.replaceAllMapped(RegExp(r'\<([\w_]+)\>'), (m) => '\$${m.group(1)}')}\';',
      '}'
    ].join();
  }

  @override
  String compileParser() {
    final key = compileParserKey();
    if(fields.isEmpty) {
      return '\'$key\': (_) => $name()';
    } else {
      return '\'$key\': (data) => ${compileParserValue(Count())}';
    }
  }

  String compileParserKey() {
    final lookup = path.replaceAllMapped(RegExp(r'\<([\w_]+)\>'), (match) => '<>');
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
}

class _Field {
  final String name;
  final String type;
  _Field(this.name, [this.type='String']);
  @override String toString() => name;
}

Directory _directory(Map<String, String> params) {
  final clientDir = params['d'] ?? params['dir'] ?? '.';
  return (clientDir == '.') ? Directory.current : Directory(clientDir);
}

Map<String, String> _params(List<String> args) {
  final params = <String, String>{};
  for(var i = 0; i < args.length; i++) {
    if(args[i].startsWith('-')) {
      if(i != args.length - 1 && !args[i+1].startsWith('-')) {
        params[args[i].substring(1)] = args[i+1];
      } else {
        params[args[i].substring(1)] = 'true';
      }
    }
  }
  return params;
}