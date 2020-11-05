import 'package:oobium_client_gen/generators/util/model.dart';

enum LibraryType { builders, models, scaffolding }

class Schema {
  final String _modelsImport;
  final List<String> _sourceImports;
  final List<Model> _models;
  Schema(String modelsImport, List<String> sourceImports, List<Model> models) :
    _modelsImport = modelsImport,
    _sourceImports = sourceImports ?? [],
    _models = models ?? []
  ;

  String get modelsImport => _modelsImport;
  List<String> get sourceImports => _sourceImports;

  List<Model> get models => _models;
}