import 'package:oobium_gen/src2/model.dart';

class ModelBuilder {

  final Model model;
  ModelBuilder(this.model);

  String get type => model.type;
  List<ModelField> get fields => model.fields;
  String get ctor => type.split('<')[0];

  String build() => '''
    class $type extends DataModel {
      
      ${fields.map((f) => "${f.type} get ${f.name} => this['${f.name}'];").join('\n')}
      
      $ctor({${fields.map((f) => '${f.isRequired ? '@required ' : ''}${f.type} ${f.name}').join(',\n')}}) : super(
        {${fields.map((f) => "'${f.name}': ${f.name}").join(',')}}
      );
      
      $ctor.copyNew($type original, {${fields.map((f) => '${f.type} ${f.name}').join(',\n')}}) : super.copyNew(original,
        {${fields.map((f) => "'${f.name}': ${f.name}").join(',')}}
      );
      
      $ctor.copyWith($type original, {${fields.map((f) => '${f.type} ${f.name}').join(',\n')}}) : super.copyWith(original,
        {${fields.map((f) => "'${f.name}': ${f.name}").join(',')}}
      );
      
      $ctor.fromJson(data, {bool newId=false}) : super.fromJson(data,
        {${fields.where((f) => f.isNotModel).map((f) => "'${f.name}'").join(',')}},
        {${fields.where((f) => f.isModel).map((f) => "'${f.name}'").join(',')}},
        newId
      );
      
      $type copyNew({
        ${fields.map((f) => '${f.type} ${f.name}').join(',\n')}
      }) => $type.copyNew(this,
        ${fields.map((f) => '${f.name}: ${f.name}').join(',\n')}
      );
      
      $type copyWith({
        ${fields.map((f) => '${f.type} ${f.name}').join(',\n')}
      }) => $type.copyWith(this,
        ${fields.map((f) => '${f.name}: ${f.name}').join(',\n')}
      );
    }
  ''';
}
