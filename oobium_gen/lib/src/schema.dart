import 'package:oobium_gen/src/model.dart';

enum LibraryType { builders, models, scaffolding }

class Schema {
  final String name;
  final List<String> _imports;
  final List<Model> _models;
  Schema(this.name, List<String> sourceImports, List<Model> models) :
    _imports = sourceImports ?? [],
    _models = models ?? []
  ;

  List<String> get imports => _imports;

  List<Model> get models => _models;
}