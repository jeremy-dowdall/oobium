import 'package:collection/collection.dart';
import 'package:oobium_datastore_gen/src/schema_parser.dart';
import 'package:xstring/xstring.dart';

class Model {

  final List<SchemaImport> _imports;
  final List<String> _options;
  final String _type;
  final List<ModelField> _fields;

  final bool _concrete;

  Model({required List<SchemaImport> imports, List<String>? options, required String type, List<ModelField>? fields}) :
    _imports = imports,
    _options = [...?options],
    _type = type,
    _fields = [...?fields],
    _expanded = null,
    _concrete = false {
    _fields.forEach((field) => field.model = this);
  }
  Model._parameterized(Model base, String typeArgument) :
    _imports = base._imports,
    _options = base._options,
    _type = '${base.name}<$typeArgument>',
    _fields = base.fields.map((f) => ModelField(
      metadata: f.metadata.toList(),
      type: f.isGeneric ? '${f.rawType}<${typeArgument}>' : f.type,
      name: f.name,
      nullable: f.isNullable,
      initializer: f._initializer
    )).toList(),
    _expanded = null,
    _concrete = true {
    _fields.forEach((field) => field.model = this);
  }

  void expandWith(Model model) {
    assert(isGeneric, 'tried to expand a non-generic model: $this');
    _expanded ??= [];
    _expanded!.add(Model._parameterized(this, model.name));
  }

  Model parameterized(String typeArgument) {
    assert(isGeneric, 'tried to parameterize a non-generic model: $this');
    return Model._parameterized(this, typeArgument);
  }

  bool get isDeclarable => isNotConcrete;
  bool get isNotDeclarable => !isDeclarable;

  bool get isIndexed => _fields.any((f) => f.name == 'id');
  bool get isNotIndexed => !isIndexed;

  String get type => _type;
  String get name => _type.split('<')[0];
  Iterable<ModelField> get fields => _fields.where((f) => f.isNotHasMany);
  Iterable<ModelField> get dataFields => fields.where((f) => f.isNotId);

  String get namePlural {
    if(_options.any((o) => o.startsWith('plural:'))) {
      return _options
          .firstWhere((o) => o.startsWith('plural:'))
          .substring(7).trim();
    }
    if(name.endsWith('y')) return '${name.substring(0, name.length - 1)}ies';
    return '${this}s';
  }

  ModelField? get idField => fields.firstWhereOrNull((f) => f.name == 'id');
  String get idType => idField?.type ?? 'ObjectId';

  List<Model>? _expanded;
  List<Model> get expanded => _expanded ?? (isGeneric ? [] : [this]);
  List<Model> get all => [this, ...?_expanded];

  bool get isGeneric => isNotConcrete && type.contains('<');
  bool get isNotGeneric => !isGeneric;

  bool get isConcrete => _concrete;
  bool get isNotConcrete => !isConcrete;

  String? get typeParameter {
    if(isConcrete) {
      return null;
    }
    final index = type.indexOf('<');
    return (index != -1) ? type.substring(index + 1, type.length - 1) : null;
  }
  String? get typeArgument {
    if(isGeneric) {
      return null;
    }
    final index = type.indexOf('<');
    return (index != -1) ? type.substring(index + 1, type.length - 1) : null;
  }

  @override
  String toString() => type;

  String get constructorFields => fields.isEmpty ? '' :
    '{${fields.map((f) => '${f.isRequired ? 'required ${f.type}' : f.isNullable ? '${f.type}?' : f.type} ${f.name}${f._initializer??''}').join(',\n')}}';
  String get constructorParams => fields.isEmpty ? '' : '${fields.map((f) => "${f.name}: ${f.name}").join(',')}';
  String get constructorMap => '{${_fields.map((f) => "'${f.name}': ${_mapValue(f)}").join(',')}}';

  String get copyFields => dataFields.isEmpty ? '' : '{${dataFields.map((f) => '${f.type}? ${f.name}').join(',\n')}}';
  String get copyParams => dataFields.isEmpty ? '' : '${dataFields.map((f) => "${f.name}: ${f.name}").join(',')}';
  String get copyNewMap => '{${_fields.where((f) => f.isNotHasMany).map((f) => "'${f.name}': ${f.name}").join(',')}}';
  String get copyWithMap => '{${dataFields.where((f) => f.isNotId).map((f) => "'${f.name}': ${f.name}").join(',')}}';

  String finderFields(String m) => dataFields.isEmpty ? 'false' :
    '${dataFields.map((f) => '(${f.name} == null || ${f.name} == $m.${f.name})').join(' && ')}'
  ;

  String compile(String dsType) => '''
    class $type extends $dsType {
      
      ${isNotIndexed ? 'ObjectId get id => this[\'_modelId\'];' : ''}
      ${_fields.map((f) => "${f.type}${f.isNullable ? '?' : ''} get ${f.name} => this['${f.name}'];").join('\n')}
      
      $name($constructorFields) : super($constructorMap);
      
      $name._(map) : super(map);
      
      $name._copyNew($type original, $constructorFields) : super.copyNew(original, $copyNewMap);
      
      $name._copyWith($type original, $copyFields) : super.copyWith(original, $copyWithMap);
      
      $type copyNew($constructorFields) => $type._copyNew(this, $constructorParams);
      
      $type copyWith($copyFields) => $type._copyWith(this, $copyParams);
    }
  ''';

  String compileAdapter() => '''
    Adapter<$name>(
      decode: $_decoder,
      encode: $_encoder,
      fields: [${_fields.map((f) => "'${f.name}'").join(',')}]
    )
  ''';

  String get _decoder {
    final decoders = _fields.map((f) => _decode(f)).whereType<String>();
    return decoders.isEmpty
      ? '(m) => $name._(m)'
      : '(m) {'
          '${decoders.join()}'
          'return $name._(m);'
        '}';
  }

  String? _decode(ModelField f) {
    String? decoder;
    decoder ??= _imports.firstWhereOrNull((i) => i.decodes(f.type))?.decoder?.replaceAll('\$', "m['${f.name}']");
    decoder ??= f.isModel ? "DataId(m['${f.name}'])" : null;
    decoder ??= f.isHasMany ? "${f.type}(key: '${f.hasManyKey}')" : null;
    decoder ??= f.isDateTime ? "DateTime.fromMillisecondsSinceEpoch(m['${f.name}'])" : null;
    decoder ??= f.jsonDecode?.replaceAll('\$', "m['${f.name}']");
    if(decoder != null) {
      if(f.isNullable) {
        return "if(m['${f.name}'] != null) { m['${f.name}'] = $decoder; }\n";
      } else {
        return "m['${f.name}'] = $decoder;\n";
      }
    }
    return null;
  }

  String get _encoder {
    final encoders = _fields.map((f) => _encode(f)).whereType<String>();
    return encoders.isEmpty
      ? '(k,v) => v'
      : '(k,v) {'
          '${encoders.join()}'
          'return v;'
        '}';
  }

  String? _encode(ModelField f) {
    String? encoder;
    encoder ??= f.jsonEncode?.replaceAll('\$', 'v');
    encoder ??= _imports.firstWhereOrNull((i) => i.encodes(f.type))?.encoder?.replaceAll('\$', 'v');
    if(encoder != null) {
      return "if(k == '${f.name}' && v is ${f.type}) return $encoder;\n";
    }
    return null;
  }

  String _mapValue(ModelField f) {
    if(f.isHasMany) {
      return "${f.type}(key: '${f.hasManyKey}')";
    }
    return f.name;
  }
}

class ModelField {

  final List<String> metadata;
  final String _type;
  final String name;
  final bool _nullable;
  final String? _initializer;
  final bool _isModel;

  ModelField({List<String>? metadata, required String type, required String name, required bool nullable, required String? initializer, bool? isModel}) :
    metadata = metadata ?? [],
    _type = type,
    name = name,
    _nullable = nullable,
    _initializer = initializer,
    _isModel = isModel ?? false
  ;

  late Model model;

  bool get isId => name == 'id';
  bool get isNotId => !isId;
  bool get isDateTime => _type == 'DateTime';
  bool get isNotDateTime => !isDateTime;
  bool get isNullable => _nullable;
  bool get isNotNullable => !isNullable;
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
  bool get isHasMany => _type == 'HasMany' || _type.startsWith('HasMany<');
  bool get isNotHasMany => !isHasMany;

  bool get isResolve => metadata.contains('resolve');
  bool get isNotResolve => !isResolve;

  bool get isRequired => metadata.contains('required') || (isNotNullable && isNotInitialized);
  bool get isNotRequired => !isRequired;

  bool get isInitialized => _initializer != null;
  bool get isNotInitialized => !isInitialized;

  bool get isGeneric => model.isGeneric && rawTypeArgument == model.typeParameter;
  bool get isNotGeneric => !isGeneric;
  String? get typeParameter => isGeneric ? model.typeParameter : null;

  bool get isParameterized => isNotGeneric && _type.contains('<');
  bool get isNotParameterized => !isParameterized;

  String? meta(String key) => metadata.firstWhereOrNull((m) => m.startsWith('$key:'))?.substring('$key:'.length).trim();

  String? get jsonDecode => meta('jsonDecode');
  String? get jsonEncode => meta('jsonEncode');

  String get hasManyKey => meta('key') ?? model.name.varName;

  String get rawType => _type.split('<')[0];
  String? get rawTypeArgument {
    final index = _type.indexOf('<');
    return (index != -1) ? _type.substring(index + 1, _type.length - 1).split('<')[0] : null;
  }

  String get type => _type;

  String? get typeArgument {
    if(isGeneric) return null;
    final index = _type.indexOf('<');
    return (index != -1) ? _type.substring(index + 1, _type.length - 1) : null;
  }

  @override
  String toString() => '$type $name';
}
