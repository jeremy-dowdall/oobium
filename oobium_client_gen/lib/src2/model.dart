class Model {

  final bool _scaffold;
  final String _type;
  final List<ModelField> _fields;

  final bool _concrete;

  Model({bool scaffold, String type, List<ModelField> fields}) :
    _scaffold = scaffold ?? false,
    _type = type,
    _fields = fields ?? [],
    _concrete = false {
    _fields.forEach((field) => field.model = this);
  }
  Model._parameterized(Model base, String typeArgument) :
    _scaffold = null,
    _type = '${base.name}<$typeArgument>',
    _fields = base.fields.map((f) => ModelField(
      metadata: f.metadata.toList(),
      type: f.isGeneric ? '${f.rawType}<${typeArgument}>' : f.type,
      name: f.name
    )).toList(),
    _concrete = true {
    _fields.forEach((field) => field.model = this);
  }

  void expandWith(Model model) {
    assert(isGeneric, 'tried to expand a non-generic model: $this');
    _expanded ??= [];
    _expanded.add(Model._parameterized(this, model.name));
  }

  Model parameterized(String typeArgument) {
    assert(isGeneric, 'tried to parameterize a non-generic model: $this');
    return Model._parameterized(this, typeArgument);
  }

  bool get isDeclarable => isNotConcrete;
  bool get isNotDeclarable => !isDeclarable;

  bool get scaffold => isDeclarable ? _scaffold : throw UnsupportedError('tried calling scaffold getter of virtual model, $type');
  String get type => _type;
  String get name => _type.split('<')[0];
  List<ModelField> get fields => _fields;

  List<Model> _expanded;
  List<Model> get expanded => _expanded ?? (isGeneric ? [] : [this]);
  List<Model> get all => [this, ...?_expanded];

  bool get isGeneric => isNotConcrete && type.contains('<');
  bool get isNotGeneric => !isGeneric;

  bool get isConcrete => _concrete;
  bool get isNotConcrete => !isConcrete;

  String get typeParameter {
    if(isConcrete) {
      return null;
    }
    final index = type.indexOf('<');
    return (index != -1) ? type.substring(index + 1, type.length - 1) : null;
  }
  String get typeArgument {
    if(isGeneric) {
      return null;
    }
    final index = type.indexOf('<');
    return (index != -1) ? type.substring(index + 1, type.length - 1) : null;
  }

  @override
  String toString() => type;
}

class ModelField {

  final List<String> metadata;
  final String _type;
  final String name;
  final bool _isModel;

  ModelField({List<String> metadata, String type, String name, bool isModel}) :
    metadata = metadata ?? [],
    _type = type,
    name = name,
    _isModel = isModel ?? false
  ;

  Model model;

  bool get isDateTime => _type == 'DateTime';
  bool get isNotDateTime => !isDateTime;
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
  bool get isModel => _isModel;
  bool get isNotModel => !isModel;

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

  String get type => _type;

  String get typeArgument {
    if(isGeneric) return null;
    final index = _type.indexOf('<');
    return (index != -1) ? _type.substring(index + 1, _type.length - 1) : null;
  }

  @override
  String toString() => '$type $name';
}
