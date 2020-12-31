import 'dart:io';

import 'package:oobium_gen/src2/generators.dart';
import 'package:oobium_gen/src2/schema_builder.dart';
import 'package:oobium_gen/src2/schema_library.dart';

Future<void> main(List<String> args) async {
  final params = _params(args);
  final clientDir = params['client'] ?? 'lib';
  final serverDir = params['server'];

  print('scanning $clientDir for schema...');
  final directory = (clientDir == '.') ? Directory.current : Directory(clientDir);
  final files = await directory.list(recursive: true).where((file) => file.path.endsWith('.schema')).toList();
  if(files.isEmpty) {
    print('no schema found');
  }
  for(var file in files) {
    final path = file.path.substring(directory.path.length + 1); // remove leading slash
    print('found $path (${file.path}... processing...');
    final modelsImport = 'import \'$path.gen.models.dart\';';
    final library = await SchemaLibrary.load(file);
    final schema = SchemaBuilder(library).build();
    // final initializersLibrary = generateInitializersLibrary(schema, modelsImport);
    final modelsLibrary = generateModelsLibrary(schema);
    // final scaffoldingLibrary = generateScaffoldingLibrary(schema, modelsImport);

    final outputs = <File>[];
    // if(initializersLibrary != null) {
    //   outputs.add(await File('$path.gen.initializers.dart').writeAsString(initializersLibrary));
    //   if(serverDir != null) outputs.add(await File('$serverDir/$path.gen.initializers.dart').writeAsString(initializersLibrary));
    // }
    if(modelsLibrary != null ) {
      outputs.add(await File('$path.gen.models.dart').writeAsString(modelsLibrary));
      if(serverDir != null) outputs.add(await File('$serverDir/$path.gen.models.dart').writeAsString(modelsLibrary));
    }
    // if(scaffoldingLibrary != null) {
    //   outputs.add(await File('$path.gen.scaffolding.dart').writeAsString(scaffoldingLibrary));
    //   outputs.add(await File('$serverDir/$path.gen.scaffolding.dart').writeAsString(scaffoldingLibrary));
    // }
    print('  $path processed. formatting...');

    final results = await Process.run('dart', ['format', ...outputs.map((f) => f.path).toList()]);
    print(results.stdout);
  }
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