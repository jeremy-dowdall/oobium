import 'dart:convert';

import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:oobium_datastore_gen/src/schema_generator.dart';
import 'package:oobium_datastore_gen/src/schema_parser.dart';

class SchemaBuilder implements Builder {
  @override
  Future build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final contents = await buildStep.readAsString(inputId);
    final lines = LineSplitter.split(contents);
    final schema = SchemaParser(lines).parse();
    if(schema != null) {
      final name = inputId.pathSegments.last.split('.')[0];
      final gen = SchemaGenerator.generate(name, schema);
      await buildStep.writeAsString(
        inputId.addExtension('.g.dart'),
        _tryFormat(gen.library)
      );
    }
  }

  @override
  final buildExtensions = const {
    '.schema': ['.schema.g.dart']
  };

  String _tryFormat(String source) {
    try {
      return DartFormatter().format(source);
    } catch(e,s) {
      print('$e\n$s');
      return source;
    }
  }
}
