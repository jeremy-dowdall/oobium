import 'dart:io';

import 'package:oobium_client_gen/src/generators.dart';
import 'package:oobium_client_gen/src/util/schema_builder.dart';
import 'package:oobium_client_gen/src/util/schema_library.dart';

Future<void> main() async {
  final pubspec = File('pubspec.yaml');
  if(await pubspec.exists()) {
    print('pubspec.yaml found...');
  } else {
    print('pubspec.yaml not found... exiting');
    exit(1);
  }

  final package = (await pubspec.readAsLines())
      .firstWhere((l) => l.startsWith('name:')).split(':')[1].trim();

  print('scanning schema for $package...');

  final directory = Directory('');
  final files = await directory.list(recursive: true).where((file) => file.path.endsWith('.schema')).toList();
  if(files.isEmpty) {
    print('no schema found');
  }
  for(var file in files) {
    final path = file.path.substring('${directory.path}/lib/'.length);
    print('found schema at $path... processing...');
    final modelsImport = 'import \'package:$package$path.models.dart\';';
    final lines = await File(file.path).readAsLines();
    final library = await SchemaLibrary.parse(lines);
    final schema = SchemaBuilder(library).build();
    final initializersLibrary = generateInitializersLibrary(schema, modelsImport);
    final modelsLibrary = generateModelsLibrary(schema);
    final scaffoldingLibrary = generateScaffoldingLibrary(schema, modelsImport);
    File('${file.path}.initializers.dart').writeAsString(initializersLibrary);
    File('${file.path}.models.dart').writeAsString(modelsLibrary);
    File('${file.path}.scaffolding.dart').writeAsString(scaffoldingLibrary);
    print('  $path processed');
  }
}
