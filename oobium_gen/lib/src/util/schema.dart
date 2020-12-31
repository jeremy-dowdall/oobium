import 'package:oobium_gen/src/util/model.dart';

enum LibraryType { builders, models, scaffolding }

class Schema {
  final List<String> _imports;
  final List<Model> _models;
  Schema(List<String> sourceImports, List<Model> models) :
    _imports = sourceImports ?? [],
    _models = models ?? []
  ;

  List<String> get imports => _imports;

  List<Model> get models => _models;
}