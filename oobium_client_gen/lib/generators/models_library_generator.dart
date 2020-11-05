import 'package:oobium_client_gen/generators/util/model_builder.dart';
import 'package:oobium_client_gen/generators/util/schema.dart';
import 'package:oobium_client_gen/generators/util/schema_generator.dart';

class ModelsLibraryGenerator extends SchemaGenerator {

  @override
  generateLibrary(Schema schema) {
    final imports = <String>[
      ...schema.sourceImports,
      'package:oobium_client/oobium_client.dart',
    ].toSet().toList()..sort();

    final models = schema.models.map((model) => ModelBuilder(model));

    return '''
      ${imports.map((import) => 'import \'$import\';').join('\n')}
      
      ${models.map((model) => model.build()).join('\n')}
    ''';
  }
}
