import 'package:oobium_client_gen/src/util/model.dart';
import 'package:oobium_client_gen/src/util/model_field.dart';
import 'package:oobium/oobium.dart' show StringExtensions;

class ScaffoldingModel {

  static String getListView(Model model) => '${model.isConcrete ? '${model.name.plural}Of${model.typeArgument}' : model.name.plural}ScaffoldingView';
  static String getDetailView(Model model) => '${model.isConcrete ? '${model.name}Of${model.typeArgument}' : model.name}ScaffoldingView';

  final Model _model;
  final String listModel;
  final String listView;
  final String listViewLabel;
  final String listViewName;
  final String detailModel;
  final String detailView;
  final String detailViewLabel;
  final String modelsVarName;
  final String modelVarName;
  ScaffoldingModel(Model model) :
    assert(model.isNotGeneric, 'tried to scaffold a generic model: $model'),
    _model = model,
    listViewLabel = model.isConcrete ? '${model.name.plural}<${model.typeArgument}>' : model.name.plural,
    listViewName = model.isConcrete ? '${model.name.plural}Of${model.typeArgument}' : model.name.plural,
    listView = getListView(model),
    listModel = '${model.isConcrete ? '${model.name.plural}Of${model.typeArgument}' : model.name.plural}ScaffoldingModel',
    detailViewLabel = model.isConcrete ? '${model.name}<${model.typeArgument}>' : model.name,
    detailView = getDetailView(model),
    detailModel = '${model.isConcrete ? '${model.name}Of${model.typeArgument}' : model.name}ScaffoldingModel',
    modelsVarName = model.name.plural.varName,
    modelVarName = model.name.varName
  ;
  String get type => _model.type;
  String get name => _model.name;
  Iterable<ModelField> get fields => _model.fields;
  ModelField get titleField => fields.firstWhere((f) => f.name == 'name' && f.isString,
      orElse: () => fields.firstWhere((f) => f.isString,
          orElse: () => fields.first));
}