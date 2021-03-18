import 'package:oobium_gen/src/model.dart';
import 'package:oobium_gen/src/schema.dart';
import 'package:oobium_gen/src/schema_library.dart';

enum LibraryType { builders, models, scaffolding }

class SchemaBuilder {
  final SchemaLibrary library;
  SchemaBuilder(this.library);

  Schema build() =>  Schema(name, imports, models);

  String get name => library.name;

  List<String> get imports {
    final imports = <String, List<String>>{};
    final fields = library.models.expand((m) => m.fields.where((f) => f.isImportedType));
    for(var field in fields) {
      imports.putIfAbsent(field.importPackage, () => []).add(field.importTypeName);
    }
    return imports.keys.map((k) => "import '$k' show ${imports[k].join(', ')};").toList();
  }

  List<Model> get models {
    return library.models.map((m) => Model(
      scaffold: m.isScaffold,
      type: m.type,
      fields: m.fields.map((f) => ModelField(
        metadata: f.options,
        type: f.type,
        name: f.name,
        isModel: library.models.any((m) => m.name == f.type)
      )).toList())
    ).toList();
  }
}
