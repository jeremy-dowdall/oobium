import 'package:oobium_client_gen/generators/util/model.dart';

class InitializersBuilder {

  final List<String> imports;
  final List<Model> models;
  InitializersBuilder({this.imports, List<Model> models}) : models = models.expand((m) => m.all).toList();

  String build() => '''
    ${imports.map((import) => 'import \'$import\';').join('\n')}
    
    extension ModelContextInitializers on ModelContext {
      void addSchemaBuilders() {
        ${models.map((model) => addSchemaBuilder(model)).join()}
      }
      void registerSchemaPersistors(Persistor persistor) {
        ${models.map((model) => registerSchemaPersistor(model)).join()}
      }
    }
  ''';

  String addSchemaBuilder(Model model) {
    if (model.isGeneric) {
      if(model.expanded.isEmpty) {
        return 'addBuilder<${model.name}>((context, data) => ${model.name}.fromJson(context, data));\n';
      }
      return '''
        addBuilder<${model.name}>((context, data) {
          final type = Json.field(data, '_type');
          ${model.expanded.map((e) => 'if(type == \'${e.typeArgument}\') return ${e.type}.fromJson(context, data);').join('\n')}
          return ${model.name}.fromJson(context, data);
        });
      ''';
    }
    return 'addBuilder<${model.type}>((context, data) => ${model.type}.fromJson(context, data));\n';
  }

  String registerSchemaPersistor(Model model) {
    if(model.isGeneric) {
      return 'register<${model.name}>(persistor);\n';
    }
    return 'register<$model>(persistor);\n';
  }
}