import 'package:oobium_client_gen/generators/util/initializers_builder.dart';
import 'package:oobium_client_gen/generators/util/schema.dart';
import 'package:oobium_client_gen/generators/util/schema_generator.dart';

class InitializersLibraryGenerator extends SchemaGenerator {

  @override
  generateLibrary(Schema schema) {
    final imports = <String>[
      'package:oobium_common/oobium_common.dart',
      'package:oobium_client/oobium_client.dart',
      schema.modelsImport,
    ].toSet().toList()..sort();

    final initializers = InitializersBuilder(imports: imports, models: schema.models);

    return initializers.build();
  }
}
