import 'dart:async';

import 'package:objectid/objectid.dart';

import 'utils.dart' as utils;

class DataIndex<T extends DataModel> {
  final Function(T model) toKey;
  final _references = <dynamic, ObjectId>{};
  DataIndex({required this.toKey});
  void clear() => _references.clear();
  ObjectId? getModelId(Object? key) => _references[key];
  void remove(T model) => _references.remove(toKey(model));
  void put(T model) => _references[toKey(model)] = model._modelId;
  Type get type => T;
}

class Models {

  final _models = <ObjectId, DataModel>{};
  final _indexes = <Type, DataIndex>{};
  StreamController<Batch>? _controller;
  var _recordCount = 0;

  Models(List<DataIndex> indexes) {
    for(final index in indexes) {
      _indexes[index.type] = index;
    }
  }

  Stream<Batch> get _stream {
    _controller ??= StreamController<Batch>.broadcast(onCancel: () => _controller = null);
    return _controller!.stream;
  }

  Future<Models> load(Stream<DataModel> models) async {
    await for(final model in models) {
      if(model.isDeleted) {
        _remove(model);
      } else {
        _put(model);
      }
    }
    return this;
  }

  Future<void> close() {
    _models.clear();
    _indexes.values.forEach((i) => i.clear());
    return _controller?.close() ?? Future.value();
  }

  bool any(Object? id) => (id != null) && _models.containsKey(_getId(id));
  bool none(Object? id) => !any(id);

  int get modelCount => _models.length;
  bool get isEmpty => _models.isEmpty;
  bool get isNotEmpty => _models.isNotEmpty;

  int get recordCount => _recordCount;
  void resetRecordCount() => _recordCount = modelCount;

  void _resolveId(DataModel m) {
    final type = m.runtimeType;
    if(_indexes.containsKey(type) && m._fields._map.containsKey('id')) {
      final id = _indexes[m.runtimeType]?.getModelId(m._fields._map['id']);
      if(id != null && m._modelId != id) {
        m._modelId = id;
      }
    }
  }

  ObjectId? _getId<T>(Object o) {
    if(o is ObjectId) return o;
    if(o is DataModel) {
      final key = o['id'];
      return (key == null) ? o._modelId
          : _indexes[o.runtimeType]?.getModelId(key) ?? o._modelId;
    }
    return _indexes[T]?.getModelId(o);
  }

  T? get<T extends DataModel>(Object? id, {T? Function()? orElse}) {
    if(id == null) return null;
    id = _getId<T>(id);
    return (_models.containsKey(id)) ? (_models[id] as T) : orElse?.call();
  }

  List<T> getAll<T extends DataModel>({bool Function(T model)? where}) {
    final v = _models.values;
    final i = (T == DataModel) ? (v as Iterable<T>) : v.whereType<T>();
    final w = (where != null) ? i.where(where) : i;
    return w.toList();
  }

  Stream<T?> stream<T extends DataModel>(Object? id) {
    return (id == null) ? Stream<T>.empty() : _stream
      .where((batch) => batch.updates.any((model) => (model is T) && (model._modelId == _getId<T>(id))))
      .map((_) => (_models[id] is T) ? (_models[id] as T) : null);
  }

  Stream<DataModelEvent<T>> streamAll<T extends DataModel>({bool Function(T model)? where}) {
    return _stream
      .where((batch) => batch.updates.any((model) => (model is T) && ((where == null) || where(model))))
      .map((batch) => DataModelEvent<T>._(this, batch, where));
  }

  Batch<T> batch<T extends DataModel>({Iterable<T>? put, Iterable<T>? remove}) {
    final batch = Batch<T>();

    if(put != null) for(var model in put) {
      _resolveId(model);
      final current = _models[model._modelId];
      if(current is T && current.isSameAs(model)) {
        batch.results.add(current);
      } else {
        _put(model);
        batch.results.add(model);
        batch.puts.add(model);
      }
      putChildren(DataModel model) {
        for(var child in model._fields.models) {
          _resolveId(child);
          if(child.isNotSameAs(_models[child._modelId])) {
            _put(child);
            batch.puts.add(child);
          }
          putChildren(child);
        }
      };
      putChildren(model);
    }

    if(remove != null) for(var model in remove) {
      _resolveId(model);
      final removed = _remove(model);
      if(removed != null) {
        batch.removes.add(removed.deleted());
        batch.results.add(removed);
      } else {
        batch.results.add(model);
      }
    }

    if(batch.isNotEmpty) {
      _controller?.add(batch);
    }

    return batch;
  }

  T _put<T extends DataModel>(T model) {
    _recordCount++;
    _models[model._modelId] = model;
    if(_indexes.containsKey(model.runtimeType)) {
      _indexes[model.runtimeType]!.put(model);
    }
    model._context = this;
    return model;
  }

  T? _remove<T extends DataModel>(T model) {
    final current = _models.remove(model._modelId);
    if(current != null) {
      _recordCount++;
      if(_indexes.containsKey(current.runtimeType)) {
        _indexes[current.runtimeType]!.remove(current);
      }
      return current as T;
    }
    model._context = null;
    return null;
  }
}

class Batch<T extends DataModel> {
  final results = <T>[];
  final puts = <DataModel>[];
  final removes = <DataModel>[];
  bool get isEmpty => puts.isEmpty && removes.isEmpty;
  bool get isNotEmpty => !isEmpty;
  Iterable<DataModel> get updates => [...puts, ...removes];
}

class DataModelEvent<T extends DataModel> {
  final Models _models;
  final Batch _batch;
  final bool Function(T model)? _where;
  DataModelEvent._(this._models, this._batch, this._where);

  List<T> get all {
    if(_where == null) {
      return _models._models.values.whereType<T>().toList();
    } else {
      return _models._models.values.whereType<T>().where(_where!).toList();
    }
  }

  List<T> get puts {
    if(_where == null) {
      return _batch.puts.whereType<T>().toList();
    } else {
      return _batch.puts.whereType<T>().where(_where!).toList();
    }
  }

  List<T> get removes {
    if(_where == null) {
      return _batch.removes.whereType<T>().toList();
    } else {
      return _batch.removes.whereType<T>().where(_where!).toList();
    }
  }
}

abstract class DataModel {
  ObjectId _modelId;
  final ObjectId _updateId;
  final DataFields _fields;
  final bool _deleted;

  DataModel([Map<String, dynamic>? fields]) :
    _deleted = fields?['_deleted'] == true,
    _modelId = _modelIdFrom(fields),
    _updateId = _updateIdFrom(fields),
    _fields = _dataFrom(fields) {
    _fields._model = this;
  }

  DataModel.copyNew(DataModel original, Map<String, dynamic>? fields) :
    _deleted = false,
    _modelId = ObjectId(),
    _updateId = ObjectId(),
    _fields = DataFields({...original._fields._map}..addAll((fields??{})..removeWhere((k,v) => v == null))) {
    _fields._model = this;
  }

  DataModel.copyWith(DataModel original, Map<String, dynamic>? fields) :
    _deleted = false,
    _modelId = original._modelId,
    _updateId = ObjectId(),
    _fields = DataFields({...original._fields._map}..addAll((fields??{})..removeWhere((k,v) => v == null))) {
    _fields._model = this;
  }

  DataModel.deleted(DataModel original) :
    _deleted = true,
    _modelId = original._modelId,
    _updateId = original._updateId,
    _fields = DataFields({});

  dynamic operator [](String key) {
    switch(key) {
      case '_modelId': return _modelId;
      case '_updateId': return _updateId;
      default: return _fields[key];
    }
  }

  Models? _context;
  bool get isAttached => _context != null;
  bool get isNotAttached => !isAttached;

  DataModel deleted();
  bool get isDeleted => _deleted;
  bool get isNotDeleted => !isDeleted;

  DateTime get createdAt => _modelId.timestamp;
  DateTime get updatedAt => _updateId.timestamp;

  @override
  bool operator ==(Object other) => identical(this, other)
    || (other is DataModel && _modelId == other._modelId && _updateId == other._updateId);

  @override
  int get hashCode => _hashCode ??= utils.finish(utils.combine(_modelId.hashCode, _updateId));
  int? _hashCode;

  bool isSameAs(other) => identical(this, other)
    || ((other is DataModel) && (_modelId == other._modelId) && _fields == other._fields);

  bool isNotSameAs(other) => !isSameAs(other);

  @override
  String toString() => '$runtimeType($_modelId)';

  static ObjectId _modelIdFrom(Map<String, dynamic>? fields) {
    final v = fields?['_modelId'];
    return (v != null) ? ObjectId.fromHexString(v) : ObjectId();
  }
  static ObjectId _updateIdFrom(Map<String, dynamic>? fields) {
    final v = fields?['_updateId'];
    return (v != null) ? ObjectId.fromHexString(v) : ObjectId();
  }
  static DataFields _dataFrom(Map<String, dynamic>? fields) {
    return DataFields({
      ...?(fields?..removeWhere((k,v) => k == '_modelId' || k == '_updateId'))
    });
  }
}

class DataFields {
  final Map<String, dynamic> _map;
  DataFields(this._map);

  late final DataModel _model;
  Models get _context {
    assert(_model._context != null, 'attempted to access context before it was set');
    return _model._context!;
  }

  Iterable<DataModel> get models => _map.values.whereType<DataModel>();

  operator [](String key) {
    final value = _map[key];
    if(value is DataModel) return value;
    if(value is DataId) return _context.get(value.id);
    if(value is HasMany) return value._attached(_context, _model);
    return value;
  }

  bool operator ==(other) => (other is DataFields) && (_map.length == other._map.length) && _map.keys.every((k) => _(k) == other._(k));

  dynamic _(String key) {
    final obj = _map[key];
    if(obj is DataId) return obj.id;
    return obj;
  }
}

class DataId {
  final ObjectId? id;
  DataId(id) : id = (id is ObjectId) ? id
      : (id != null) ? ObjectId.fromHexString('$id') : null;
}

class HasMany<C extends DataModel> {
  final String key;
  Models? _context;
  DataModel? _parent;
  HasMany({required this.key}) : _context = null, _parent = null;

  HasMany<C> _attached(Models context, DataModel parent) {
    _context = context;
    _parent = parent;
    return this;
  }

  C firstWhere(bool test(C element), {C orElse()?}) {
    return _context!.getAll<C>().firstWhere(
      (c) => (c[key] == _parent) && test(c),
      orElse: orElse
    );
  }

  List<C> toList() {
    return _context!.getAll<C>().where((c) => c[key] == _parent).toList();
  }
}
