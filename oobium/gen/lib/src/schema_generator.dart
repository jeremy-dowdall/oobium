import 'package:oobium_gen/src/schema_parser.dart';
import 'package:string_x/string_x.dart';

enum LibraryType { builders, models, scaffolding }

class SchemaGenerator {

  final String library;
  SchemaGenerator._(this.library);

  factory SchemaGenerator.generate(String name, Schema schema) {
    final imports = <String>[
      ...schema.imports,
      "import 'package:oobium/oobium.dart';",
    ].toSet().toList()..sort();

    final dsName = '${name.camelCase}Data';
    final dsPath = name.underscored;

    final schemaLibrary =
      '${imports.join('\n')}'
      'class $dsName extends DataStore {'
        '$dsName(String path) : super(\'\$path/$dsPath\', ['
          '${schema.models.map((m) => '(data) => ${m.name}.fromJson(data)').join(',\n')}'
        ']);'
      '}'
      '${schema.models.map((m) => m.compile()).join('\n')}'
    ;

    return SchemaGenerator._(schemaLibrary);
  }

}
