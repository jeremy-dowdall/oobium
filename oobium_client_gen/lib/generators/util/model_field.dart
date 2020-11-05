import 'package:oobium_client_gen/generators/util/model.dart';

class ModelField {

  final bool _virtual;
  final List<String> metadata;
  final String _type;
  final String name;

  ModelField({List<String> metadata, String type, String name}) :
    metadata = metadata ?? [],
    _type = type,
    name = name,
    _virtual = false
  ;
  ModelField.virtual({String type, String name}) :
    metadata = [],
    _type = type,
    name = name,
    _virtual = true
  ;

  Model model;
  Model linkedModel;
  ModelField _linkedField;
  ModelField get linkedField => _linkedField;
  set linkedField(ModelField value) {
    _linkedField = value..model = linkedModel;
  }

  String get parent {
    for(var i = model.fields.indexOf(this) - 1; i >= 0; i--) {
      if(model.fields[i].isNotChildLink) return model.fields[i].name;
    }
    return null;
  }

  bool get isAccess => _type == 'Access' || _type.startsWith('Access<');
  bool get isNotAccess => !isAccess;
  bool get isChildLink => _type == 'ChildLink' || _type.startsWith('ChildLink<');
  bool get isNotChildLink => !isChildLink;
  bool get isDateTime => _type == 'DateTime';
  bool get isNotDateTime => !isDateTime;
  bool get isLink => _type == 'Link' || _type.startsWith('Link<');
  bool get isNotLink => !isLink;
  bool get isNullable => isDateTime; // there may be more... but right now this is it
  bool get isNotNullable => !isNullable;
  bool get isResolve => metadata.any((meta) => meta == 'resolve');
  bool get isNotResolve => !isResolve;
  bool get isString => _type == 'String';
  bool get isNotString => !isString;
  bool get isIterable => _type == 'Iterable' || _type.startsWith('Iterable<');
  bool get isNotIterable => !isIterable;
  bool get isList => _type == 'List' || _type.startsWith('List<');
  bool get isNotList => !isList;
  bool get isBool => _type == 'bool';
  bool get isNotBool => !isBool;
  bool get isInt => _type == 'int';
  bool get isNotInt => !isInt;
  bool get isNum => _type == 'num';
  bool get isNotNum => !isNum;
  bool get isDouble => _type == 'double';
  bool get isNotDouble => !isDouble;

  bool get isHasMany => _type == 'HasMany' || _type.startsWith('HasMany<');
  bool get isNotHasMany => !isHasMany;

  bool get isVirtual => _virtual;
  bool get isNotVirtual => !isVirtual;

  bool get isGeneric => model.isGeneric && rawTypeArgument == model.typeParameter;
  bool get isNotGeneric => !isGeneric;
  String get typeParameter => isGeneric ? model.typeParameter : null;

  bool get isParameterized => isNotGeneric && _type.contains('<');
  bool get isNotParameterized => !isParameterized;

  String get rawType => _type.split('<')[0];
  String get rawTypeArgument {
    final index = _type.indexOf('<');
    return (index != -1) ? _type.substring(index + 1, _type.length - 1).split('<')[0] : null;
  }

  String get type {
    if((isLink || isHasMany) && linkedModel != null) {
      if(linkedModel.isGeneric) return '${_type.substring(0, _type.length - 1)}<${model.name}>>';
      if(linkedModel.isConcrete) return '${_type.substring(0, _type.length - 1)}<${linkedModel.typeArgument}>>';
    }
    return _type;
  }

  String get typeArgument {
    if(isGeneric) return null;
    if((isLink || isHasMany) && linkedModel != null) {
      if(linkedModel.isGeneric) return '${rawTypeArgument}<${model.name}>';
      if(linkedModel.isConcrete) return '${rawTypeArgument}<${linkedModel.typeArgument}>';
    }
    final index = _type.indexOf('<');
    return (index != -1) ? _type.substring(index + 1, _type.length - 1) : null;
  }

  @override
  String toString() => '$type $name${isVirtual ? '-virtual' : ''}';
}
