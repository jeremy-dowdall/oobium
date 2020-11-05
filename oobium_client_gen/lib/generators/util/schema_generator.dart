import 'package:build/build.dart';
import 'package:oobium_client_gen/generators/util/schema.dart';
import 'package:oobium_client_gen/generators/util/schema_builder.dart';
import 'package:source_gen/source_gen.dart';

abstract class SchemaGenerator extends Generator {

  generateLibrary(Schema schema);

  @override
  generate(LibraryReader library, BuildStep buildStep) {
    final schema = SchemaBuilder(library).load();
    if(schema == null) {
      return null;
    } else {
      return generateLibrary(schema);
    }
  }
}
