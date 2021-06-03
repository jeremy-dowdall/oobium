import 'dart:convert';

import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:oobium_gen/src/schema_generator.dart';
import 'package:oobium_gen/src/schema_parser.dart';

class SchemaBuilder implements Builder {
  @override
  Future build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final contents = await buildStep.readAsString(inputId);
    final lines = LineSplitter.split(contents);
    final schema = SchemaParser(lines).parse();
    if(schema != null) {
      final formatter = DartFormatter();
      final gen = SchemaGenerator.generate(inputId.pathSegments.last, schema);
      await buildStep.writeAsString(
        inputId.addExtension('.g.dart'),
        formatter.format(gen.library)
      );
    }
  }

  @override
  final buildExtensions = const {
    '.schema': ['.schema.g.dart']
  };
}
