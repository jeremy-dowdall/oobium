import 'package:oobium_gen/src/util/model_field.dart';

class Model {

  final bool _scaffold;
  final String _owner;
  final String _type;
  final List<ModelField> _fields;

  final bool _concrete;
  final bool _virtual;

  Model({bool scaffold, String owner, String type, List<ModelField> fields}) :
    _scaffold = scaffold ?? false,
    _owner = owner,
    _type = type,
    _fields = fields ?? [],
    _concrete = false,
    _virtual = false {
    _fields.forEach((field) => field.model = this);
  }
  Model.virtual(String type) :
    _scaffold = null,
    _owner = null,
    _type = type,
    _fields = null,
    _concrete = false,
    _virtual = true
  ;
  Model._parameterized(Model base, String typeArgument) :
    _scaffold = null,
    _owner = null,
    _type = '${base.name}<$typeArgument>',
    _fields = base.fields.map((f) => ModelField(
      metadata: f.metadata.toList(),
      type: f.isGeneric ? '${f.rawType}<${typeArgument}>' : f.type,
      name: f.name
    )).toList(),
    _concrete = true,
    _virtual = false {
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

  bool get isDeclarable => isNotVirtual && isNotConcrete;
  bool get isNotDeclarable => !isDeclarable;
  bool get isVirtual => _virtual;
  bool get isNotVirtual => !isVirtual;

  bool get scaffold => isDeclarable ? _scaffold : throw UnsupportedError('tried calling scaffold getter of virtual model, $type');
  String get owner => isDeclarable ? _owner : throw UnsupportedError('tried calling owner getter of virtual model, $type');
  String get type => _type;
  String get name => _type.split('<')[0];
  List<ModelField> get fields => isNotVirtual ? _fields : throw UnsupportedError('tried calling fields getter of virtual model, $type');

  List<Model> _expanded;
  List<Model> get expanded => _expanded ?? (isGeneric ? [] : [this]);
  List<Model> get all => [this, ...?_expanded];

  bool get isGeneric => isNotConcrete && isNotVirtual && type.contains('<');
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
  String toString() => '$type${isVirtual ? '-virtual' : ''}';
}