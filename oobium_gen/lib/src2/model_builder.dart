import 'package:oobium_gen/src2/model.dart';

class ModelBuilder {

  final Model model;
  ModelBuilder(this.model);

  String get type => model.type;
  List<ModelField> get fields => model.fields;
  String get ctor => type.split('<')[0];

  String get copyAsMethod {
    if(model.isGeneric) {
      final typeParameter = (model.typeParameter == 'T') ? 'P' : 'T';
      return '''
      
        ${model.name}<$typeParameter> copyAs<$typeParameter>({
          String id,
          ${fields.map((f) {
            if(f.isGeneric) return '${f.rawType}<$typeParameter> ${f.name}';
            else return '${f.type} ${f.name}';
          }).join(',\n')}
        }) => ${model.name}<$typeParameter>(
          id: id,
          ${fields.map((f) => f.copyAs).join(',\n')}
        );
        
      ''';
    }
    return '';
  }

  String build() => '''
    class $type extends DataModel {
      
      ${fields.map((f) => "${f.type} get ${f.name} => this['${f.name}'];").join('\n')}
      
      $ctor({${fields.map((f) => '${f.type} ${f.name}').join(',\n')}}) : super(
        {${fields.map((f) => "'${f.name}': ${f.name}").join(',')}}
      );
      
      $ctor.copyNew($type original, {${fields.map((f) => '${f.type} ${f.name}').join(',\n')}}) : super.copyNew(original,
        {${fields.map((f) => "'${f.name}': ${f.name}").join(',')}}
      );
      
      $ctor.copyWith($type original, {${fields.map((f) => '${f.type} ${f.name}').join(',\n')}}) : super.copyWith(original,
        {${fields.map((f) => "'${f.name}': ${f.name}").join(',')}}
      );
      
      $ctor.fromJson(data) : super.fromJson(data,
        {${fields.where((m) => m.isNotModel).map((f) => "'${f.name}'").join(',')}},
        {${fields.where((m) => m.isModel).map((f) => "'${f.name}'").join(',')}},
      );
      
      $copyAsMethod
      
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

extension ModelBuilderExtensions on Model {
  ModelField get titleField => fields.firstWhere((f) => f.name == 'name' && f.isString,
    orElse: () => fields.firstWhere((f) => f.isString,
      orElse: () => fields.first));
}

extension ModelBuilderFieldExtensions on ModelField {
  String get assignment {
    if(isIterable || isList) {
      return '$name = $type.unmodifiable($name ?? [])';
    }
    if(isDateTime) {
      if(name.endsWith('Date') || name.endsWith('On')) {
        return '$name = ($name != null) ? DateTime($name.year, $name.month, $name.day) : null';
      }
      if(name.endsWith('Time')) {
        return '$name = ($name != null) ? DateTime(0, 0, 0, $name.hour, $name.minute, $name.second) : null';
      }
      return '$name = $name';
    }
    if(isModel) {
      return '\'$name\': $name';
    }
    return '$name = $name$defaultValue';
  }

  String get copyAs {
    if(isGeneric) {
      return '$name: $name';
    }
    if(isNullable) {
      return '$name: nullable($name, this.$name)';
    }
    return '$name: $name ?? this.$name';
  }

  String get copyWith {
    if(isNullable) {
      return '$name: nullable($name, this.$name)';
    }
    return '$name: $name ?? this.$name';
  }

  String get declaration {
    if(isModel) {
      return '$type get $name => context.get<$type>(\'$name\');';
    }
    return 'final $type $name;';
  }

  String get defaultValue {
    if(isIterable) return ' ?? $type.unmodifiable([])';
    if(isList)     return ' ?? $type.unmodifiable([])';
    if(isBool)     return ' ?? false';
    if(isInt)      return ' ?? 0';
    if(isNum)      return ' ?? 0';
    if(isDouble)   return ' ?? 0.0';
    return '';
  }

  String get isSameAs {
    if(isModel) {
      return 'context.id(\'$name\') == other.context.id(\'$name\')';
    }
    return '($name == other.$name)';
  }

  String get fromJson {
    if(isIterable || isList) {
      return '$name = Json.toList(data, \'$name\', (v) => v)$defaultValue';
    }
    if(isDateTime) {
      return '$name = Json.toDateTime(data, \'$name\')';
    }
    if(isModel) {
      return '\'$name\'';
    }
    return '$name = Json.field(data, \'$name\')$defaultValue';
  }

  String get param {
    return '${type} ${name}';
  }

  String get toJson {
    if(isModel) {
      return '..[\'$name\'] = context.id(\'$name\')';
    }
    return '..[\'$name\'] = Json.from($name)';
  }
}