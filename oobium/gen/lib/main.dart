import 'dart:io';

import 'package:oobium_gen/src/schema_generator.dart';
import 'package:oobium_gen/src/schema_parser.dart';

Future<void> main(List<String> args) async {
  final params = _params(args);
  final directory = _directory(params);

  print('scanning ${directory.path} for schema...');
  final files = await directory.list(recursive: true).where((file) => file.path.endsWith('.schema')).toList();
  if(files.isEmpty) {
    print('no schema found');
  }

  for(var file in files) {
    final path = file.path.substring(directory.path.length + 1); // remove leading slash
    final name = file.path.substring(file.parent.path.length + 1).split('.')[0];
    print('found $name (${file.path})... processing...');

    final lines = await (file as File).readAsLines();
    final schema = SchemaParser(lines).parse();

    if(schema != null) {
      final gen = SchemaGenerator.generate(name, schema);
      final outputs = <File>[
        await File('$path.schema.g.dart').writeAsString(gen.library)
      ];
      print('  $path processed.');

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
