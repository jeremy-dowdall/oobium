import 'dart:io';

import 'package:oobium_routing_gen/src/routes_generator.dart';

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
      final gen = RoutesGenerator.generate('$name.dart', routes);
      final outputs = <File>[
        await File('${directory.path}/${path.replaceAll('.dart', '.g.dart')}').writeAsString(gen.routesLibrary),
        if(lines.contains('const genProvider = true;'))
          await File('${directory.path}/${path.replaceAll('.dart', '.g.provider.dart')}').writeAsString(gen.providerLibrary),
      ];
      print('  $path processed. formatting...');

      final results = await Process.run('dart', ['format', ...outputs.map((f) => f.path).toList()]);
      print(results.stdout);
    }
  }
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
