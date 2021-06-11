import 'dart:async';

import 'package:objectid/objectid.dart';
import 'package:oobium_datastore/src/datastore.dart';

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

  final _builders = <String, Function(Map data)>{};
  final _models = <ObjectId, DataModel>{};
  final _indexes = <Type, DataIndex>{};
  StreamController<Batch>? _controller;
  var _recordCount = 0;

  Models(List<Function(Map data)> builders, List<DataIndex> indexes) {
    _builders['DataModel'] = (data) => DataModel.fromJson(data, data.keys.map((k) => '$k').toSet(), {}, false);
    for(var builder in builders) {
      final type = builder.runtimeType.toString().split(' => ')[1];
      _builders[type] = builder;
    }
    for(final index in indexes) {
      _indexes[index.type] = index;
    }
  }

  Stream<Batch> get _stream {
    _controller ??= StreamController<Batch>.broadcast(onCancel: () => _controller = null);
    return _controller!.stream;
  }

  Future<Models> load(Stream<DataRecord> records) async {
    await for(var record in records) {
      final model = _build(record);
      if(record.isDelete) {
        _remove(model);
      } else {
        _put(model);
      }
    }
    return this;
  }

  void loadAll(Iterable<DataRecord> records) => batch(
    put: records.where((r) => r.isNotDelete).map((r) => _build(r)),
    remove: records.where((r) => r.isDelete).map((r) => _build(r)),
  );

  Future<void> close() {
    _models.clear();
    _indexes.values.forEach((i) => i.clear());
    return _controller?.close() ?? Future.value();
  }

  bool any(Object? id) => _models.containsKey(_resolve(id));
  bool none(Object? id) => !any(id);

  int get modelCount => _models.length;
  bool get isEmpty => _models.isEmpty;
  bool get isNotEmpty => _models.isNotEmpty;

  int get recordCount => _recordCount;
  void resetRecordCount() => _recordCount = modelCount;

  Object? _resolve<T>(Object? o) => (o is ObjectId) ? o : (o is DataModel) ? o._modelId : _indexes[T]?.getModelId(o);

  T? get<T extends DataModel>(Object? id, {T? Function()? orElse}) {
    id = _resolve<T>(id);
    return (_models.containsKey(id)) ? (_models[id] as T) : orElse?.call();
  }

  Iterable<T> getAll<T extends DataModel>() => (T == DataModel) ? (_models.values as Iterable<T>) : _models.values.whereType<T>();

  Stream<T?> stream<T extends DataModel>(Object? id) {
    id = _resolve<T>(id);
    return _stream
      .where((batch) => batch.updates.any((model) => (model is T) && (model._modelId == id)))
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
      final current = _models[model._modelId];
      if(current is T && current.isSameAs(model)) {
        batch.results.add(current);
      } else {
        _put(model);
        batch.results.add(model);
        batch.puts.add(model);
      }
      for(var member in model._fields.models) {
        // TODO deep child search; this only handles 1 layer
        if(member.isNotSameAs(_models[member._modelId])) {
          _put(member);
          batch.puts.add(member);
        }
      }
    }

    if(remove != null) for(var model in remove) {
      final removed = _remove(model);
      if(removed != null) {
        batch.removes.add(removed);
        batch.results.add(removed);
      } else {
        batch.results.add(model);
      }
    }

    for(var model in batch.puts) {
      model._fields._context = this;
    }

    if(batch.isNotEmpty) {
      _controller?.add(batch);
    }

    return batch;
  }

  DataModel _build(DataRecord record) {
    final builder = _builders[record.type] ?? _builders['DataModel'];
    assert(builder != null, 'no builder registered for ${record.type}');
    final value = builder!(record.data);
    assert(value is DataModel, 'builder did not return a DataModel: $value');
    return (value as DataModel).._fields._context = this;
  }

  T _put<T extends DataModel>(T model) {
    _recordCount++;
    _models[model._modelId] = model;
    if(_indexes.containsKey(model.runtimeType)) {
      _indexes[model.runtimeType]!.put(model);
    }
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
    return null;
  }
}

class Batch<T extends DataModel> {
  final results = <T>[];
  final puts = <DataModel>[];
  final removes = <DataModel>[];
  bool get isEmpty => puts.isEmpty && removes.isEmpty;
  bool get isNotEmpty => !isEmpty;
  Iterable<DataRecord> get records => [...puts.map((m) => m.toDataRecord()), ...removes.map((m) => m.toDataRecord(delete: true))];
  Iterable<DataModel> get updates => [...puts, ...removes];
}

class DataModelEvent<T extends DataModel> {
  final Models _models;
  final Batch _batch;
  final bool Function(T model)? _where;
  DataModelEvent._(this._models, this._batch, this._where);

  Iterable<T> get all {
    if(_where == null) {
      return _models._models.values.whereType<T>();
    } else {
      return _models._models.values.whereType<T>().where(_where!);
    }
  }

  Iterable<T> get puts {
    if(_where == null) {
      return _batch.puts.whereType<T>();
    } else {
      return _batch.puts.whereType<T>().where(_where!);
    }
  }

  Iterable<T> get removes {
    if(_where == null) {
      return _batch.removes.whereType<T>();
    } else {
      return _batch.removes.whereType<T>().where(_where!);
    }
  }
}

///
/// remove JsonModel
/// implement == and hashCode
///   models are equal if same: id, modCount(?)
///     this would be locally unique, how to do global sync?
///     modCount could be another ObjectId... it would be a globally unique updateId... hmmm...
/// isSame/isNotSame are used during a put: if they have the same id and same data, don't bother
///   they won't be equal, but will be the same
///   the existing object should be returned from the put
class DataModel {
  ObjectId _modelId;
  late ObjectId _updateId;
  final DataFields _fields;

  DataModel([Map<String, dynamic>? fields]) :
    _modelId = ObjectId(),
    _updateId = ObjectId(),
    _fields = DataFields(fields ?? {});

  DataModel.copyNew(DataModel original, Map<String, dynamic>? fields) :
    _modelId = ObjectId(),
    _updateId = ObjectId(),
    _fields = DataFields({...original._fields._map}..addAll((fields??{})..removeWhere((k,v) => v == null)));

  DataModel.copyWith(DataModel original, Map<String, dynamic>? fields) :
    _modelId = original._modelId,
    _updateId = ObjectId(),
    _fields = DataFields({...original._fields._map}..addAll((fields??{})..removeWhere((k,v) => v == null)));

  DataModel.fromJson(data, Set<String> fields, Set<String> modelFields, bool newId) :
    _modelId = newId ? ObjectId() : ObjectId.fromHexString(data['_modelId']),
    _updateId = newId ? ObjectId() : ObjectId.fromHexString(data['_updateId']),
    _fields = DataFields({
      for(final k in fields.where((k) => k != '_modelId' && k != '_updateId'))
        k: data[k],
      for(final k in modelFields)
        k: DataId.fromJson(data[k])
    });

  dynamic operator [](String key) {
    switch(key) {
      case '_modelId': return _modelId;
      case '_updateId': return _updateId;
      default: return _fields[key];
    }
  }

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

  DataRecord toDataRecord({bool delete=false}) {
    final data = delete ? null : toJson();
    data?.removeWhere((k,v) => (k == '_modelId') || (k == '_updateId') || (v == null) || (v is String && v.isEmpty) || (v is Iterable && v.isEmpty) || (v is Map && v.isEmpty));
    return DataRecord('$_modelId', '$_updateId', '$runtimeType', data);
  }

  Map<String, dynamic> toJson() => {
    '_modelId': '$_modelId',
    '_updateId': '$_updateId',
    for(var e in _fields._map.entries) e.key: e.value
  };

  @override
  String toString() => '$runtimeType($_modelId)';
}

class DataId {
  final ObjectId? id;
  DataId(this.id);
  DataId.fromJson(String? id) : id = (id != null) ? ObjectId.fromHexString(id) : null;
  String toJson() => '$id';
}

class DataFields {
  final Map<String, dynamic> _map;
  DataFields(this._map);

  late Models _context;

  Iterable<DataModel> get models => _map.values.whereType<DataModel>();

  operator [](String key) {
    final value = _map[key];
    if(value is DataModel) return value;
    if(value is DataId) return _context.get(value.id);
    return value;
  }

  bool operator ==(other) => (other is DataFields) && (_map.length == other._map.length) && _map.keys.every((k) => _(k) == other._(k));

  dynamic _(String key) {
    final obj = _map[key];
    if(obj is DataId) return obj.id;
    return obj;
  }
}
