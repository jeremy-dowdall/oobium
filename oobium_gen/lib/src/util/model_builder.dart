import 'package:oobium_gen/src/util/model.dart';
import 'package:oobium_gen/src/util/model_field.dart';

class ModelBuilder {

  final Model model;
  ModelBuilder(this.model);

  String get owner => model.owner;
  String get type => model.type;
  List<ModelField> get fields => model.fields;
  String get ctor => type.split('<')[0];

  Iterable<ModelField> get hasMany => fields.where((field) => field.isHasMany);
  Iterable<ModelField> get notHasMany => fields.where((field) => field.isNotHasMany);
  Iterable<ModelField> get resolveFields => fields.where((field) => field.isResolve);
  bool get resolvers => hasMany.isNotEmpty;

  String get implements => resolveFields.isNotEmpty ? 'implements Resolvable<$type>' : '';

  String get copyAsMethod {
    if(model.isGeneric) {
      final typeParameter = (model.typeParameter == 'T') ? 'P' : 'T';
      return '''
      
        ${model.name}<$typeParameter> copyAs<$typeParameter>({
          String id,
          Link<User> owner,
          Access access,
          ${notHasMany.map((f) {
            if(f.isGeneric) return '${f.rawType}<$typeParameter> ${f.name}';
            else return '${f.type} ${f.name}';
          }).join(',\n')}
        }) => ${model.name}<$typeParameter>(
          this.context,
          id: id,
          owner: owner ?? this.owner,
          access: access ?? this.access,
          ${notHasMany.map((f) => f.copyAs).join(',\n')}
        );
        
      ''';
    }
    return '';
  }

  String get resolvableMethods {
    final resolve = this.resolveFields;
    if(resolve.isNotEmpty) {
      return '''
      
        @override
        bool get isResolved => ${resolve.map((e) => '${e.name}.isResolved').join(' && ')};
        
        @override
        bool get isNotResolved => !isResolved;
      
        @override
        Future<$type> resolved() async {
          return isResolved ? this : copyWith(${resolve.map((e) => '${e.name}: await ${e.name}.resolved()').join(', ')});
        }
        
      ''';
    }
    return '';
  }

  String get hasManyResolvers {
    return '''{
      ${hasMany.map((f) => 'this.${f.name}.resolver = HasManyResolver<${f.typeArgument}>(this, \'${f.linkedField.name}\', (m) => m.copyWith(${f.linkedField.name}: link));\n').join()}
    }''';
  }

  String build() => '''
    class ${model.type} extends Model<$type, $owner> $implements {
      
      ${fields.map((f) => 'final ${f.type} ${f.name};\n').join()}
      
      $ctor(ModelContext context, {
        String id,
        Link<$owner> owner,
        Access access,
        ${fields.map((f) => f.param).join(',\n')}
      }) :
        ${fields.map((f) => f.assignment).join()}
        super(context, id, owner, access)
        ${resolvers ? hasManyResolvers : ';'}
      
      $ctor.fromJson(ModelContext context, data) :
        ${fields.map((f) => f.fromJson).join()}
        super.fromJson(context, data)
        ${resolvers ? hasManyResolvers : ';'}
      $copyAsMethod
      @override
      ${model.type} copyWith({
        String id,
        Link<User> owner,
        Access access,
        ${fields.map((f) => f.param).join(',\n')}
      }) => ${model.type}(
        this.context,
        id: id ?? this.id,
        owner: owner ?? this.owner,
        access: access ?? this.access,
        ${fields.map((f) => f.copyWith).join(',\n')}
      );
      
      @override
      bool isSameAs(other) =>
        (runtimeType == other?.runtimeType)
        && (id == other.id)
        && ${notHasMany.map((f) => f.isSameAs).join('\n&& ')}
      ;
      bool isNotSameAs(other) => !isSameAs(other);

      @override
      Map<String, dynamic> toJson() => super.toJson()
        ${model.isGeneric ? '..[\'_type\'] = Json.from(${model.typeParameter})' : ''}
        ${notHasMany.map((f) => f.name).map((name) => '..[\'$name\'] = Json.from($name)').join('\n')}
      ;
      $resolvableMethods
      @override
      String toString() => '${model.type}(id: \$id)';
    }
  ''';
}

extension ModelExtensions on Model {
  ModelField get titleField => fields.firstWhere((f) => f.name == 'name' && f.isString,
    orElse: () => fields.firstWhere((f) => f.isString,
      orElse: () => fields.first));
}

extension ModelFieldBuilderExtensions on ModelField {
  String get assignment {
    if(isIterable || isList) {
      return '$name = $type.unmodifiable($name ?? []),\n';
    }
    if(isChildLink) {
      return '$name = $type(context, id: $name?.id, parentId: $parent?.id, model: $name?.model),\n';
    }
    if(isLink) {
      return '$name = $type(context, id: $name?.id, model: $name?.model),\n';
    }
    if(isHasMany) {
      return '$name = $type($name),\n';
    }
    if(isDateTime) {
      if(name.endsWith('Date') || name.endsWith('On')) {
        return '$name = ($name != null) ? DateTime($name.year, $name.month, $name.day) : null,\n';
      }
      if(name.endsWith('Time')) {
        return '$name = ($name != null) ? DateTime(0, 0, 0, $name.hour, $name.minute, $name.second) : null,\n';
      }
      return '$name = $name,\n';
    }
    return '$name = $name ?? $defaultValue,\n';
  }

  String get param {
    if(isHasMany) {
      return 'Iterable<${typeArgument}> ${name}';
    } else {
      return '${type} ${name}';
    }
  }
  String get copyAs {
    if(isGeneric) {
      return '$name: $name';
    }
    if(isChildLink) {
      return '$name: $name ?? ((($parent?.id ?? this.$parent.id) != this.$name.parentId) ? $type(context, parentId: ($parent?.id ?? this.$parent.id), id: this.$name.id) : this.$name)';
    }
    if(isNullable) {
      return '$name: nullable($name, this.$name)';
    }
    return '$name: $name ?? this.$name';
  }

  String get copyWith {
    if(isHasMany) {
      return '$name: nullable($name, this.$name.models)';
    }
    if(isChildLink) {
      return '$name: $name ?? ((($parent?.id ?? this.$parent.id) != this.$name.parentId) ? $type(context, parentId: ($parent?.id ?? this.$parent.id), id: this.$name.id) : this.$name)';
    }
    if(isNullable) {
      return '$name: nullable($name, this.$name)';
    }
    return '$name: $name ?? this.$name';
  }

  String get isSameAs {
    return '($name == other.$name)';
  }

  String get defaultValue {
    if(isString)   return "''";
    if(isIterable) return '$type.unmodifiable([])';
    if(isList)     return '$type.unmodifiable([])';
    if(isBool)     return 'false';
    if(isInt)      return '0';
    if(isNum)      return '0';
    if(isDouble)   return '0.0';
    if(isAccess)   return 'Access.private';
    return 'null';
  }

  String get fromJson {
    if(isIterable || isList) {
      return '$name = Json.toList(data, \'$name\', (v) => v) ?? $defaultValue,\n';
    }
    if(isChildLink) {
      return '$name = Json.field(data, \'$name\', (v) => $type(context, parentId: Json.field(data, \'$parent\'), id: v)),\n';
    }
    if(isLink) {
      return '$name = Json.field(data, \'$name\', (v) => $type(context, id: v)),\n';
    }
    if(isHasMany) {
      return '$name = $type(),\n';
    }
    if(isDateTime) {
      return '$name = Json.toDateTime(data, \'$name\'),\n';
    }
    return '$name = Json.field(data, \'$name\') ?? $defaultValue,\n';
  }
}